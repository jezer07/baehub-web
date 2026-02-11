require "bigdecimal"

class ExpensesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_couple!
  before_action :set_expense, only: [ :show, :edit, :update, :destroy ]

  def filters
  end

  def apply_filters
    redirect_params = {}
    redirect_params[:start_date] = params[:start_date] if params[:start_date].present?
    redirect_params[:end_date] = params[:end_date] if params[:end_date].present?
    redirect_params[:spender_id] = params[:spender_id] if params[:spender_id].present?
    recede_or_redirect_to expenses_path(redirect_params)
  end

  def index
    @balance_data = current_user.couple.calculate_balance

    @expenses = current_user.couple.expenses.includes(:spender, :expense_shares)
                           .order(incurred_on: :desc)

    start_date = nil
    end_date = nil

    if params[:start_date].present? && params[:end_date].present?
      start_date = Date.parse(params[:start_date]) rescue nil
      end_date = Date.parse(params[:end_date]) rescue nil
      @expenses = @expenses.between_dates(start_date, end_date) if start_date && end_date
    end

    if params[:spender_id].present?
      @expenses = @expenses.by_spender(params[:spender_id])
    end

    @settlements = current_user.couple.settlements.includes(:payer, :payee)
                              .order(settled_on: :desc, created_at: :desc)

    if start_date && end_date
      @settlements = @settlements.where(settled_on: start_date..end_date)
    end

    if params[:spender_id].present?
      @settlements = @settlements.where(payer_id: params[:spender_id])
    end

    transactions_from_expenses = @expenses.map do |expense|
      {
        type: :expense,
        date: expense.incurred_on,
        created_at: expense.created_at,
        object: expense
      }
    end

    transactions_from_settlements = @settlements.map do |settlement|
      {
        type: :settlement,
        date: settlement.settled_on,
        created_at: settlement.created_at,
        object: settlement
      }
    end

    @transactions = (transactions_from_expenses + transactions_from_settlements)
      .sort_by { |t| [ -t[:date].to_time.to_i, -t[:created_at].to_i ] }
  end

  def show
  end

  def new
    @expense = current_user.couple.expenses.build
    @expense.spender = current_user
    @expense.incurred_on = Date.today
    @couple_users = current_user.couple.users.to_a
  end

  def create
    @expense = current_user.couple.expenses.build(expense_params)
    @expense.spender = current_user
    success = false

    begin
      Expense.transaction do
        if @expense.save
          if calculate_and_create_shares
            log_expense_activity("added expense '#{@expense.title}' for #{@expense.formatted_amount}", @expense)
            success = true
          else
            raise ActiveRecord::Rollback
          end
        else
          raise ActiveRecord::Rollback
        end
      end

      if success
        recede_or_redirect_to expenses_path, notice: "Expense was successfully created."
      else
        @couple_users = current_user.couple.users.to_a
        flash.now[:alert] = @expense.errors.full_messages.join(", ")
        render :new, status: :unprocessable_entity
      end
    rescue StandardError => e
      log_exception(e, context: "expenses#create")
      @expense.errors.add(:base, generic_error_message)
      @couple_users = current_user.couple.users.to_a
      flash.now[:alert] = @expense.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @couple_users = current_user.couple.users.to_a
  end

  def update
    begin
      Expense.transaction do
        @expense.expense_shares.destroy_all
        if @expense.update(expense_params)
          if calculate_and_create_shares
            log_expense_activity("updated expense '#{@expense.title}'", @expense)
            recede_or_redirect_to expense_path(@expense), notice: "Expense was successfully updated."
          else
            raise ActiveRecord::Rollback
          end
        else
          raise ActiveRecord::Rollback
        end
      end

      unless @expense.errors.empty?
        @couple_users = current_user.couple.users.to_a
        flash.now[:alert] = @expense.errors.full_messages.join(", ")
        render :edit, status: :unprocessable_entity
      end
    rescue StandardError => e
      log_exception(e, context: "expenses#update")
      @expense.errors.add(:base, generic_error_message)
      @couple_users = current_user.couple.users.to_a
      flash.now[:alert] = @expense.errors.full_messages.join(", ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    expense_title = @expense.title

    begin
      Expense.transaction do
        log_expense_activity("deleted expense '#{expense_title}'", @expense)
        @expense.destroy
      end
      recede_or_redirect_to expenses_path, notice: "Expense was successfully deleted."
    rescue StandardError => e
      log_exception(e, context: "expenses#destroy")
      redirect_to expenses_path, alert: generic_error_message
    end
  end

  private

  def ensure_couple!
    unless current_user.couple
      redirect_to new_pairing_path, alert: "Create your shared space before managing expenses."
    end
  end

  def set_expense
    @expense = current_user.couple.expenses.includes(:spender, expense_shares: :user).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to expenses_path, alert: "Expense not found."
  end

  def expense_params
    params.require(:expense).permit(:title, :amount_cents, :incurred_on, :notes, :split_strategy, :spender_id)
  end

  def shares_params
    shares_hash = params.require(:expense)[:shares]
    return [] unless shares_hash

    shares_hash.values.map do |share|
      share.permit(:user_id, :amount_cents, :amount, :percentage).to_h.symbolize_keys
    end
  end

  def calculate_and_create_shares
    case @expense.split_strategy
    when "equal"
      couple_users = @expense.couple.users.to_a
      base_amount = @expense.amount_cents / couple_users.size
      remainder = @expense.amount_cents % couple_users.size

      couple_users.each_with_index do |user, index|
        share_amount = base_amount + (index < remainder ? 1 : 0)
        @expense.expense_shares.create!(user: user, amount_cents: share_amount)
      end
    when "percentage"
      shares_data = Array(shares_params).map { |s| s.respond_to?(:to_unsafe_h) ? s.to_unsafe_h : s }.map(&:symbolize_keys)
      total_percentage = shares_data.sum { |s| s[:percentage].to_f }

      Rails.logger.info("total percentage: #{total_percentage}")

      if (total_percentage - 100.0).abs > 0.01
        @expense.errors.add(:base, "Percentages must sum to 100%")
        return false
      end

      shares_data.each do |share_data|
        @expense.expense_shares.create!(
          user_id: share_data[:user_id],
          percentage: share_data[:percentage]
        )
      end
    when "custom_amounts"
      shares_data = Array(shares_params).map { |s| s.respond_to?(:to_unsafe_h) ? s.to_unsafe_h : s }.map(&:symbolize_keys)
      shares_data.each do |share_data|
        share_data[:amount_cents] = amount_cents_from_share(share_data)
      end

      total_amount = shares_data.sum { |s| s[:amount_cents].to_i }

      if total_amount != @expense.amount_cents
        @expense.errors.add(:base, "Share amounts must sum to total expense amount")
        return false
      end

      shares_data.each do |share_data|
        @expense.expense_shares.create!(
          user_id: share_data[:user_id],
          amount_cents: share_data[:amount_cents]
        )
      end
    end

    true
  end

  def log_expense_activity(action, expense)
    ActivityLog.create!(
      couple: current_user.couple,
      user: current_user,
      action: action,
      subject: expense,
      metadata: { origin: "expenses" }
    )
  end

  def amount_cents_from_share(share_data)
    return share_data[:amount_cents].to_i if share_data[:amount_cents].present?

    amount_value = share_data[:amount]
    return 0 if amount_value.blank?

    (BigDecimal(amount_value.to_s) * 100).round
  rescue ArgumentError
    0
  end
end

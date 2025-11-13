class JointAccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_couple!
  before_action :set_joint_account, only: [:show, :edit, :update, :destroy, :ledger, :balances, :borrow, :settle]

  def index
    @joint_accounts = current_user.couple.joint_accounts
                                   .includes(:created_by, :joint_account_memberships)
                                   .order(created_at: :desc)
  end

  def show
    @balances = @joint_account.joint_account_balances.includes(:user)
    @recent_entries = @joint_account.joint_account_ledger_entries
                                    .includes(:initiator, :counterparty)
                                    .order(created_at: :desc)
                                    .limit(10)
    @recent_settlements = @joint_account.joint_account_settlements
                                        .includes(:settled_by)
                                        .order(settlement_date: :desc, created_at: :desc)
                                        .limit(5)
  end

  def new
    @joint_account = current_user.couple.joint_accounts.build
    @couple_users = current_user.couple.users.to_a
  end

  def create
    result = JointAccounts::Creator.new(
      couple: current_user.couple,
      creator_user: current_user,
      params: joint_account_creation_params
    ).call

    if result[:success]
      log_activity("created joint account: #{result[:joint_account].name}", result[:joint_account])
      redirect_to joint_account_path(result[:joint_account]), notice: "Joint account created successfully."
    else
      @joint_account = current_user.couple.joint_accounts.build(name: joint_account_params[:name])
      @couple_users = current_user.couple.users.to_a
      flash.now[:alert] = "Error creating joint account: #{result[:errors].join(', ')}"
      render :new, status: :unprocessable_entity
    end
  rescue StandardError => e
    @joint_account = current_user.couple.joint_accounts.build(name: joint_account_params[:name])
    @couple_users = current_user.couple.users.to_a
    flash.now[:alert] = "Error creating joint account: #{e.message}"
    render :new, status: :unprocessable_entity
  end

  def edit
    @couple_users = current_user.couple.users.to_a
  end

  def update
    if @joint_account.update(joint_account_update_params)
      log_activity("updated joint account: #{@joint_account.name}", @joint_account)
      redirect_to joint_account_path(@joint_account), notice: "Joint account updated successfully."
    else
      @couple_users = current_user.couple.users.to_a
      flash.now[:alert] = "Error updating joint account: #{@joint_account.errors.full_messages.join(', ')}"
      render :edit, status: :unprocessable_entity
    end
  rescue StandardError => e
    @couple_users = current_user.couple.users.to_a
    flash.now[:alert] = "Error updating joint account: #{e.message}"
    render :edit, status: :unprocessable_entity
  end

  def destroy
    account_name = @joint_account.name
    
    if @joint_account.joint_account_ledger_entries.unsettled.any?
      redirect_to joint_account_path(@joint_account), alert: "Cannot delete joint account with unsettled transactions."
      return
    end

    @joint_account.update!(status: :archived)
    log_activity("archived joint account: #{account_name}", @joint_account)
    redirect_to joint_accounts_path, notice: "Joint account archived successfully."
  rescue StandardError => e
    redirect_to joint_account_path(@joint_account), alert: "Error archiving joint account: #{e.message}"
  end

  def ledger
    @ledger_entries = @joint_account.joint_account_ledger_entries
                                    .includes(:initiator, :counterparty)
                                    .order(created_at: :desc)

    if params[:status] == "settled"
      @ledger_entries = @ledger_entries.settled
    elsif params[:status] == "unsettled"
      @ledger_entries = @ledger_entries.unsettled
    end

    @ledger_entries = @ledger_entries.page(params[:page]).per(25) if defined?(Kaminari)
  end

  def balances
    @balances = @joint_account.joint_account_balances
                              .includes(:user)
                              .order("balance_cents DESC")
  end

  def borrow
    result = JointAccounts::BorrowProcessor.new(
      joint_account: @joint_account,
      initiator_user: current_user,
      params: borrow_params
    ).call

    if result[:success]
      log_activity("recorded borrow transaction on #{@joint_account.name}: #{format_amount(result[:ledger_entry].amount_cents, result[:ledger_entry].currency)}", result[:ledger_entry])
      
      respond_to do |format|
        format.html { redirect_to joint_account_path(@joint_account), notice: "Borrow transaction recorded successfully." }
        format.json { render json: { success: true, ledger_entry: result[:ledger_entry] }, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to joint_account_path(@joint_account), alert: "Error recording borrow transaction: #{result[:errors].join(', ')}" }
        format.json { render json: { success: false, errors: result[:errors] }, status: :unprocessable_entity }
      end
    end
  rescue StandardError => e
    respond_to do |format|
      format.html { redirect_to joint_account_path(@joint_account), alert: "Error recording borrow transaction: #{e.message}" }
      format.json { render json: { success: false, errors: [e.message] }, status: :unprocessable_entity }
    end
  end

  def settle
    result = JointAccounts::SettlementProcessor.new(
      joint_account: @joint_account,
      settled_by_user: current_user,
      params: settlement_params
    ).call

    if result[:success]
      log_activity("settled transactions on #{@joint_account.name}: #{format_amount(result[:settlement].total_amount_cents, result[:settlement].currency)}", result[:settlement])
      
      respond_to do |format|
        format.html { redirect_to joint_account_path(@joint_account), notice: "Settlement recorded successfully." }
        format.json { render json: { success: true, settlement: result[:settlement] }, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to joint_account_path(@joint_account), alert: "Error recording settlement: #{result[:errors].join(', ')}" }
        format.json { render json: { success: false, errors: result[:errors] }, status: :unprocessable_entity }
      end
    end
  rescue StandardError => e
    respond_to do |format|
      format.html { redirect_to joint_account_path(@joint_account), alert: "Error recording settlement: #{e.message}" }
      format.json { render json: { success: false, errors: [e.message] }, status: :unprocessable_entity }
    end
  end

  private

  def ensure_couple!
    return if current_user.couple

    redirect_to new_pairing_path, alert: "Create your shared space before managing joint accounts."
    return false
  end

  def set_joint_account
    @joint_account = current_user.couple.joint_accounts.includes(:joint_account_memberships).find(params[:id])
    
    unless @joint_account.member?(current_user)
      redirect_to joint_accounts_path, alert: "You are not a member of this joint account."
      return false
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to joint_accounts_path, alert: "Joint account not found."
    return false
  end

  def joint_account_params
    params.require(:joint_account).permit(:name, :currency, :status, settings: {})
  end

  def joint_account_creation_params
    {
      name: params[:joint_account][:name],
      currency: params[:joint_account][:currency],
      settings: params[:joint_account][:settings] || {},
      member_ids: params[:joint_account][:member_ids] || []
    }
  end

  def joint_account_update_params
    params.require(:joint_account).permit(:name, :currency, :status, settings: {})
  end

  def borrow_params
    amount_in_dollars = params[:amount_cents].to_f
    amount_in_cents = (amount_in_dollars * 100).round

    {
      direction: params[:direction],
      amount_cents: amount_in_cents,
      currency: params[:currency],
      description: params[:description],
      counterparty_id: params[:counterparty_id],
      metadata: params[:metadata] || {}
    }
  end

  def settlement_params
    amount_in_dollars = params[:total_amount_cents].to_f
    amount_in_cents = (amount_in_dollars * 100).round

    {
      ledger_entry_ids: params[:ledger_entry_ids] || [],
      total_amount_cents: amount_in_cents,
      currency: params[:currency],
      settlement_date: params[:settlement_date],
      notes: params[:notes],
      payment_method: params[:payment_method],
      metadata: params[:metadata] || {}
    }
  end

  def log_activity(action, subject)
    ActivityLog.create!(
      couple: current_user.couple,
      user: current_user,
      action: action,
      subject: subject,
      metadata: { origin: "joint_accounts" }
    )
  end

  def format_amount(cents, currency)
    symbol = CurrencyCatalog.symbol_for(currency)
    "#{symbol}#{sprintf('%.2f', cents / 100.0)}"
  end
end

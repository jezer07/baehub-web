# app/controllers/api/v1/expenses_controller.rb
module Api
  module V1
    class ExpensesController < Api::BaseController
      before_action :set_couple
      before_action :set_expense, only: [ :show, :update, :destroy ]

      # GET /api/v1/expenses
      def index
        @expenses = @couple.expenses.order(incurred_on: :desc, created_at: :desc)

        # Apply filters
        @expenses = @expenses.by_spender(params[:spender_id]) if params[:spender_id].present?
        @expenses = @expenses.between_dates(params[:start_date], params[:end_date]) if params[:start_date].present? && params[:end_date].present?

        render json: {
          expenses: @expenses.map { |expense| expense_detail(expense) },
          balance: @couple.calculate_balance
        }
      end

      # GET /api/v1/expenses/:id
      def show
        render json: { expense: expense_detail(@expense) }
      end

      # POST /api/v1/expenses
      def create
        @expense = @couple.expenses.build(expense_params)
        @expense.spender = current_user

        ActiveRecord::Base.transaction do
          if @expense.save
            create_expense_shares!
            log_activity("created", @expense)

            render json: { expense: expense_detail(@expense) }, status: :created
          else
            render_errors(@expense.errors.full_messages)
          end
        end
      end

      # PATCH/PUT /api/v1/expenses/:id
      def update
        ActiveRecord::Base.transaction do
          if @expense.update(expense_params)
            update_expense_shares!
            log_activity("updated", @expense)

            render json: { expense: expense_detail(@expense) }
          else
            render_errors(@expense.errors.full_messages)
          end
        end
      end

      # DELETE /api/v1/expenses/:id
      def destroy
        @expense.destroy
        log_activity("deleted", @expense)

        render json: { message: "Expense deleted successfully" }
      end

      private

      def set_couple
        @couple = current_user.couple
        render_error("No couple associated with this user", :forbidden) unless @couple
      end

      def set_expense
        @expense = @couple.expenses.find(params[:id])
      end

      def expense_params
        params.require(:expense).permit(:title, :amount_cents, :incurred_on, :notes, :split_strategy, shares: {})
      end

      def create_expense_shares!
        case @expense.split_strategy
        when "equal"
          # Split equally among couple members
          amount_per_person = @expense.amount_cents / @couple.users.count
          @couple.users.each do |user|
            @expense.expense_shares.create!(user: user, amount_cents: amount_per_person)
          end
        when "percentage"
          # Use percentage from params
          params[:expense][:shares]&.each do |user_id, percentage|
            amount = (@expense.amount_cents * percentage.to_f / 100).round
            @expense.expense_shares.create!(user_id: user_id, percentage: percentage, amount_cents: amount)
          end
        when "custom_amounts"
          # Use custom amounts from params
          params[:expense][:shares]&.each do |user_id, amount_cents|
            @expense.expense_shares.create!(user_id: user_id, amount_cents: amount_cents)
          end
        end
      end

      def update_expense_shares!
        @expense.expense_shares.destroy_all
        create_expense_shares!
      end

      def expense_detail(expense)
        {
          id: expense.id,
          title: expense.title,
          amount_cents: expense.amount_cents,
          amount: expense.amount,
          currency: @couple.default_currency,
          incurred_on: expense.incurred_on,
          notes: expense.notes,
          split_strategy: expense.split_strategy,
          spender: {
            id: expense.spender.id,
            name: expense.spender.name,
            email: expense.spender.email
          },
          shares: expense.expense_shares.map do |share|
            {
              user_id: share.user_id,
              user_name: share.user.name,
              amount_cents: share.amount_cents,
              amount: share.amount_cents / 100.0,
              percentage: share.percentage
            }
          end,
          created_at: expense.created_at,
          updated_at: expense.updated_at
        }
      end

      def log_activity(action, expense)
        @couple.activity_logs.create!(
          user: current_user,
          action: "expense_#{action}",
          subject: expense,
          metadata: { title: expense.title }
        )
      end
    end
  end
end

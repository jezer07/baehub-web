# app/controllers/api/v1/settlements_controller.rb
module Api
  module V1
    class SettlementsController < Api::BaseController
      before_action :set_couple
      before_action :set_settlement, only: [ :show, :update, :destroy ]

      # GET /api/v1/settlements
      def index
        @settlements = @couple.settlements.order(settled_on: :desc, created_at: :desc)

        # Apply date filter
        if params[:start_date].present? && params[:end_date].present?
          @settlements = @settlements.where(settled_on: params[:start_date]..params[:end_date])
        end

        render json: {
          settlements: @settlements.map { |settlement| settlement_detail(settlement) },
          balance: @couple.calculate_balance
        }
      end

      # GET /api/v1/settlements/:id
      def show
        render json: { settlement: settlement_detail(@settlement) }
      end

      # POST /api/v1/settlements
      def create
        @settlement = @couple.settlements.build(settlement_params)

        ActiveRecord::Base.transaction do
          if @settlement.save
            log_activity("created", @settlement)
            render json: { settlement: settlement_detail(@settlement) }, status: :created
          else
            render_errors(@settlement.errors.full_messages)
          end
        end
      end

      # PATCH/PUT /api/v1/settlements/:id
      def update
        ActiveRecord::Base.transaction do
          if @settlement.update(settlement_params)
            log_activity("updated", @settlement)
            render json: { settlement: settlement_detail(@settlement) }
          else
            render_errors(@settlement.errors.full_messages)
          end
        end
      end

      # DELETE /api/v1/settlements/:id
      def destroy
        @settlement.destroy
        log_activity("deleted", @settlement)

        render json: { message: "Settlement deleted successfully" }
      end

      private

      def set_couple
        @couple = current_user.couple
        render_error("No couple associated with this user", :forbidden) unless @couple
      end

      def set_settlement
        @settlement = @couple.settlements.find(params[:id])
      end

      def settlement_params
        params.require(:settlement).permit(:payer_id, :payee_id, :amount_cents, :settled_on, :notes)
      end

      def settlement_detail(settlement)
        {
          id: settlement.id,
          amount_cents: settlement.amount_cents,
          amount: settlement.amount,
          currency: @couple.default_currency,
          settled_on: settlement.settled_on,
          notes: settlement.notes,
          payer: {
            id: settlement.payer.id,
            name: settlement.payer.name,
            email: settlement.payer.email
          },
          payee: {
            id: settlement.payee.id,
            name: settlement.payee.name,
            email: settlement.payee.email
          },
          created_at: settlement.created_at,
          updated_at: settlement.updated_at
        }
      end

      def log_activity(action, settlement)
        @couple.activity_logs.create!(
          user: current_user,
          action: "settlement_#{action}",
          subject: settlement,
          metadata: {
            payer: settlement.payer.name,
            payee: settlement.payee.name,
            amount: settlement.amount
          }
        )
      end
    end
  end
end

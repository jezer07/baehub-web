class SettlementsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_couple!
  before_action :set_settlement, only: [ :show, :edit, :update, :destroy ]
  before_action :set_form_context, only: [ :new, :create, :edit, :update ]

  def index
    @settlements = current_user.couple.settlements.includes(:payer, :payee)
                              .order(settled_on: :desc, created_at: :desc)

    if params[:start_date].present? && params[:end_date].present?
      start_date = Date.parse(params[:start_date]) rescue nil
      end_date = Date.parse(params[:end_date]) rescue nil
      @settlements = @settlements.where(settled_on: start_date..end_date) if start_date && end_date
    end
  end

  def show
  end

  def new
    @settlement = current_user.couple.settlements.build
    @settlement.payer = current_user
    @settlement.settled_on = Date.today
  end

  def edit
  end

  def create
    @settlement = current_user.couple.settlements.build(settlement_params)

    begin
      Settlement.transaction do
        if @settlement.save
          log_settlement_activity("recorded payment of #{@settlement.formatted_amount} from #{@settlement.payer.name} to #{@settlement.payee.name}", @settlement)

          respond_to do |format|
            format.html { redirect_to expenses_path, notice: "Settlement recorded successfully." }
            format.turbo_stream { redirect_to expenses_path, notice: "Settlement recorded successfully." }
          end
        else
          respond_to do |format|
            format.html { render :new, status: :unprocessable_entity }
            format.turbo_stream { render turbo_stream: turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { type: :alert, message: "Error recording settlement: #{@settlement.errors.full_messages.join(', ')}" }) }
          end
        end
      end
    rescue StandardError => e
      respond_to do |format|
        format.html { redirect_to new_settlement_path, alert: "Error recording settlement: #{e.message}" }
        format.turbo_stream { render turbo_stream: turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { type: :alert, message: "Error recording settlement: #{e.message}" }) }
      end
    end
  end

  def update
    begin
      Settlement.transaction do
        if @settlement.update(settlement_params)
          @settlement.reload
          log_settlement_activity("updated payment to #{@settlement.formatted_amount} from #{@settlement.payer.name} to #{@settlement.payee.name}", @settlement)

          respond_to do |format|
            format.html { redirect_to expenses_path, notice: "Settlement updated successfully." }
            format.turbo_stream { redirect_to expenses_path, notice: "Settlement updated successfully." }
          end
        else
          respond_to do |format|
            format.html { render :edit, status: :unprocessable_entity }
            format.turbo_stream { render turbo_stream: turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { type: :alert, message: "Error updating settlement: #{@settlement.errors.full_messages.join(', ')}" }) }
          end
        end
      end
    rescue StandardError => e
      respond_to do |format|
        format.html { redirect_to edit_settlement_path(@settlement), alert: "Error updating settlement: #{e.message}" }
        format.turbo_stream { render turbo_stream: turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { type: :alert, message: "Error updating settlement: #{e.message}" }) }
      end
    end
  end

  def destroy
    settlement_description = "#{@settlement.payer.name} paid #{@settlement.payee.name} #{@settlement.formatted_amount}"

    begin
      Settlement.transaction do
        log_settlement_activity("deleted settlement: #{settlement_description}", @settlement)
        @settlement.destroy
      end
      redirect_to expenses_path, notice: "Settlement was successfully deleted."
    rescue StandardError => e
      redirect_to expenses_path, alert: "Error deleting settlement: #{e.message}"
    end
  end

  private

  def ensure_couple!
    unless current_user.couple
      redirect_to new_pairing_path, alert: "Create your shared space before managing settlements."
    end
  end

  def set_settlement
    @settlement = current_user.couple.settlements.includes(:payer, :payee).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to expenses_path, alert: "Settlement not found."
  end

  def set_form_context
    @couple_users = current_user.couple.users.to_a
    @partner = @couple_users.find { |user| user.id != current_user.id }
  end

  def settlement_params
    params.require(:settlement).permit(:payer_id, :payee_id, :amount_dollars, :settled_on, :notes)
  end

  def log_settlement_activity(action, settlement)
    ActivityLog.create!(
      couple: current_user.couple,
      user: current_user,
      action: action,
      subject: settlement,
      metadata: { origin: "settlements" }
    )
  end
end

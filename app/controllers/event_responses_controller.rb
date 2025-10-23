class EventResponsesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_couple!
  before_action :set_event
  before_action :set_event_response, only: [:update]

  def create
    status_param = event_response_params[:status]
    
    unless EventResponse.statuses.key?(status_param)
      respond_to do |format|
        format.html { redirect_to event_path(@event), alert: "Invalid RSVP status." }
        format.turbo_stream { render turbo_stream: turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { type: :alert, message: "Invalid RSVP status." }), status: :unprocessable_entity }
      end
      return
    end

    @event_response = @event.event_responses.find_or_initialize_by(user: current_user)
    @event_response.status = status_param

    EventResponse.transaction do
      if @event_response.save
        action_message = "#{@event_response.status} RSVP for event '#{@event.title}'"
        log_event_response_activity(action_message, @event_response)

        respond_to do |format|
          format.html { redirect_to event_path(@event), notice: "RSVP updated successfully." }
          format.turbo_stream
        end
      else
        respond_to do |format|
          format.html { redirect_to event_path(@event), alert: @event_response.errors.full_messages.to_sentence }
          format.turbo_stream { render turbo_stream: turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { type: :alert, message: @event_response.errors.full_messages.to_sentence }) }
        end
      end
    end
  rescue StandardError => e
    respond_to do |format|
      format.html { redirect_to event_path(@event), alert: "Error updating RSVP: #{e.message}" }
      format.turbo_stream { render turbo_stream: turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { type: :alert, message: "Error updating RSVP: #{e.message}" }) }
    end
  end

  def update
    status_param = event_response_params[:status]
    
    unless EventResponse.statuses.key?(status_param)
      respond_to do |format|
        format.html { redirect_to event_path(@event), alert: "Invalid RSVP status." }
        format.turbo_stream { render turbo_stream: turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { type: :alert, message: "Invalid RSVP status." }), status: :unprocessable_entity }
      end
      return
    end

    @event_response.status = status_param

    EventResponse.transaction do
      if @event_response.save
        action_message = "changed RSVP to #{@event_response.status} for event '#{@event.title}'"
        log_event_response_activity(action_message, @event_response)

        respond_to do |format|
          format.html { redirect_to event_path(@event), notice: "RSVP changed successfully." }
          format.turbo_stream
        end
      else
        respond_to do |format|
          format.html { redirect_to event_path(@event), alert: @event_response.errors.full_messages.to_sentence }
          format.turbo_stream { render turbo_stream: turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { type: :alert, message: @event_response.errors.full_messages.to_sentence }) }
        end
      end
    end
  rescue StandardError => e
    respond_to do |format|
      format.html { redirect_to event_path(@event), alert: "Error changing RSVP: #{e.message}" }
      format.turbo_stream { render turbo_stream: turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { type: :alert, message: "Error changing RSVP: #{e.message}" }) }
    end
  end

  private

  def ensure_couple!
    return if current_user.couple

    redirect_to new_pairing_path, alert: "Create your shared space before managing events."
    return
  end

  def set_event
    @event = current_user.couple.events.find(params[:event_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to events_path, alert: "Event not found."
    return
  end

  def set_event_response
    @event_response = @event.event_responses.find(params[:id])
    
    unless @event_response.user_id == current_user.id
      redirect_to event_path(@event), alert: "You can only manage your own responses."
      return
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to event_path(@event), alert: "Response not found."
    return
  end

  def event_response_params
    params.permit(:status)
  end

  def log_event_response_activity(action, event_response)
    ActivityLog.create!(
      couple: current_user.couple,
      user: current_user,
      action: action,
      subject: event_response,
      metadata: { origin: "event_responses", event_id: @event.id, event_title: @event.title }
    )
  end
end


# app/controllers/api/v1/events_controller.rb
module Api
  module V1
    class EventsController < Api::BaseController
      before_action :set_couple
      before_action :set_event, only: [ :show, :update, :destroy, :respond ]

      # GET /api/v1/events
      def index
        @events = @couple.events.order(starts_at: :asc)

        # Apply filters
        @events = @events.where(category: params[:category]) if params[:category].present?
        if params[:start_date].present? && params[:end_date].present?
          @events = @events.where(starts_at: params[:start_date]..params[:end_date])
        end

        # Apply sorting
        case params[:sort_by]
        when "starts_at"
          @events = @events.order(starts_at: :asc)
        when "created_at"
          @events = @events.order(created_at: :desc)
        end

        render json: { events: @events.map { |event| event_detail(event) } }
      end

      # GET /api/v1/events/:id
      def show
        render json: { event: event_detail(@event) }
      end

      # POST /api/v1/events
      def create
        @event = @couple.events.build(event_params)
        @event.creator = current_user

        if @event.save
          log_activity("created", @event)
          render json: { event: event_detail(@event) }, status: :created
        else
          render_errors(@event.errors.full_messages)
        end
      end

      # PATCH/PUT /api/v1/events/:id
      def update
        if @event.update(event_params)
          log_activity("updated", @event)
          render json: { event: event_detail(@event) }
        else
          render_errors(@event.errors.full_messages)
        end
      end

      # DELETE /api/v1/events/:id
      def destroy
        @event.destroy
        log_activity("deleted", @event)

        render json: { message: "Event deleted successfully" }
      end

      # POST /api/v1/events/:id/respond
      def respond
        response = @event.event_responses.find_or_initialize_by(user: current_user)
        response.status = params[:status]
        response.responded_at = Time.current

        if response.save
          log_activity("responded_to", @event)
          render json: { response: response_detail(response) }
        else
          render_errors(response.errors.full_messages)
        end
      end

      private

      def set_couple
        @couple = current_user.couple
        render_error("No couple associated with this user", :forbidden) unless @couple
      end

      def set_event
        @event = @couple.events.find(params[:id])
      end

      def event_params
        params.require(:event).permit(
          :title, :description, :starts_at, :ends_at, :all_day,
          :location, :category, :color, :requires_response, :recurrence_rule
        )
      end

      def event_detail(event)
        {
          id: event.id,
          title: event.title,
          description: event.description,
          starts_at: event.starts_at,
          ends_at: event.ends_at,
          all_day: event.all_day,
          location: event.location,
          category: event.category,
          color: event.color,
          requires_response: event.requires_response,
          recurrence_rule: event.recurrence_rule,
          creator: {
            id: event.creator.id,
            name: event.creator.name,
            email: event.creator.email
          },
          responses: event.event_responses.map { |r| response_detail(r) },
          created_at: event.created_at,
          updated_at: event.updated_at
        }
      end

      def response_detail(response)
        {
          id: response.id,
          user: {
            id: response.user.id,
            name: response.user.name,
            email: response.user.email
          },
          status: response.status,
          responded_at: response.responded_at
        }
      end

      def log_activity(action, event)
        @couple.activity_logs.create!(
          user: current_user,
          action: "event_#{action}",
          subject: event,
          metadata: { title: event.title }
        )
      end
    end
  end
end

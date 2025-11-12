class EventsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_couple!
  before_action :set_event, only: [ :show, :edit, :update, :destroy ]
  before_action :build_recurrence_rule, only: [ :create, :update ]

  def index
    @events = current_user.couple.events.includes(:event_responses, :creator)

    if params[:start_date].present? && params[:end_date].present?
      begin
        start_date = params[:start_date].to_date
        end_date = params[:end_date].to_date
        @events = @events.between_dates(start_date, end_date)
      rescue ArgumentError
      end
    end

    case params[:filter]
    when "upcoming"
      @events = @events.upcoming
    when "past"
      @events = @events.past
    when "current_week"
      @events = @events.current_week
    when "future"
      @events = @events.future
    end

    case params[:sort]
    when "starts_at_desc"
      @events = @events.order(starts_at: :desc)
    when "title_asc"
      @events = @events.order(:title)
    when "title_desc"
      @events = @events.order(title: :desc)
    else
      @events = @events.order(starts_at: :asc)
    end

    @current_date = if params[:date].present?
      begin
        Date.parse(params[:date])
      rescue ArgumentError
        Date.today
      end
    else
      Date.today
    end

    events_collection = @events.to_a
    list_range = list_range_bounds(events_collection)
    @events = sort_occurrences(EventOccurrenceBuilder.expand(
      events_collection,
      range_start: list_range.first,
      range_end: list_range.last,
      per_event_limit: 365
    ))

    calendar_range = calendar_range_bounds(@current_date, params[:view])
    @calendar_events = EventOccurrenceBuilder.expand(
      events_collection,
      range_start: calendar_range.first,
      range_end: calendar_range.last,
      per_event_limit: 365
    )
  end

  def show
  end

  def new
    @event = current_user.couple.events.build
    @event.creator = current_user

    default_start_time = Time.current.in_time_zone(current_user.couple.timezone).change(min: 0, sec: 0) + 1.hour
    @event.starts_at = default_start_time
    @event.ends_at = default_start_time + 1.hour
  end

  def create
    @event = current_user.couple.events.build(event_params)
    @event.creator = current_user

    if @recurrence_rule_to_assign
      @event.recurrence_rule = @recurrence_rule_to_assign
    end

    normalize_event_times

    Event.transaction do
      if @event.save
        formatted_date = @event.starts_at.in_time_zone(current_user.couple.timezone).strftime("%B %-d, %Y")
        log_event_activity("created event '#{@event.title}' on #{formatted_date}", @event)
        redirect_to events_path, notice: "Event created successfully."
      else
        flash.now[:alert] = @event.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    end
  rescue StandardError => e
    @event.errors.add(:base, e.message)
    flash.now[:alert] = @event.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    @event.assign_attributes(event_params)
    normalize_event_times

    Event.transaction do
      if @event.save
        activity_message = if @event.saved_changes.key?("recurrence_rule")
          if @event.recurrence_rule.present?
            "set event '#{@event.title}' to recur #{@event.recurrence_summary.downcase}"
          else
            "removed recurrence from event '#{@event.title}'"
          end
        elsif @event.saved_changes.key?("starts_at") || @event.saved_changes.key?("ends_at")
          formatted_date = @event.starts_at.in_time_zone(current_user.couple.timezone).strftime("%B %-d, %Y")
          "rescheduled event '#{@event.title}' to #{formatted_date}"
        elsif @event.saved_changes.key?("all_day")
          all_day_status = @event.all_day? ? "all-day" : "timed"
          "changed event '#{@event.title}' to #{all_day_status}"
        else
          "updated event '#{@event.title}'"
        end

        log_event_activity(activity_message, @event)
        redirect_to @event, notice: "Event updated successfully."
      else
        flash.now[:alert] = @event.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end
  rescue StandardError => e
    @event.errors.add(:base, e.message)
    flash.now[:alert] = @event.errors.full_messages.to_sentence
    render :edit, status: :unprocessable_entity
  end

  def destroy
    event_title = @event.title

    Event.transaction do
      log_event_activity("deleted event '#{event_title}'", @event)
      @event.destroy
      redirect_to events_path, notice: "Event deleted successfully."
    end
  rescue StandardError => e
    redirect_to events_path, alert: "Error deleting event: #{e.message}"
  end

  private

  def ensure_couple!
    return if current_user.couple

    redirect_to new_pairing_path, alert: "Create your shared space before managing events."
    nil
  end

  def set_event
    @event = current_user.couple.events.includes(:event_responses, :creator).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to events_path, alert: "Event not found."
    nil
  end

  def event_params
    params.require(:event).permit(:title, :description, :starts_at, :ends_at, :all_day)
  end

  def log_event_activity(action, event)
    ActivityLog.create!(
      couple: current_user.couple,
      user: current_user,
      action: action,
      subject: event,
      metadata: { origin: "events" }
    )
  end

  def normalize_event_times
    return unless @event.all_day

    couple_timezone = current_user.couple.timezone

    if @event.starts_at.present?
      @event.starts_at = @event.starts_at.in_time_zone(couple_timezone).beginning_of_day
    end

    if @event.ends_at.present?
      @event.ends_at = @event.ends_at.in_time_zone(couple_timezone).end_of_day
    else
      @event.ends_at = @event.starts_at.in_time_zone(couple_timezone).end_of_day
    end
  end

  def build_recurrence_rule
    return unless params[:event]

    recurring = params[:event][:recurring]
    frequency = params[:event].delete(:recurrence_frequency)
    interval = params[:event].delete(:recurrence_interval)
    end_date = params[:event].delete(:recurrence_end_date)

    if recurring == "0"
      @recurrence_rule_to_assign = nil
      @event.recurrence_rule = nil if @event
      return
    end

    if frequency.present?
      interval = interval.presence || "1"
      end_date = end_date.presence || "never"
      built_rule = "#{frequency}:#{interval}:#{end_date}"

      if @event
        @event.recurrence_rule = built_rule
      else
        @recurrence_rule_to_assign = built_rule
      end
    else
      @recurrence_rule_to_assign = nil
      @event.recurrence_rule = nil if @event
    end
  end

  def parse_date_param(key)
    return nil unless params[key].present?

    Date.parse(params[key])
  rescue ArgumentError
    nil
  end

  def list_range_bounds(events)
    explicit_start = parse_date_param(:start_date)
    explicit_end = parse_date_param(:end_date)

    event_starts = events.map { |event| event.starts_at&.to_date }.compact
    event_ends = events.map { |event| (event.ends_at || event.starts_at)&.to_date }.compact

    min_date = event_starts.min || Date.today
    max_date = event_ends.max || min_date

    start_date = explicit_start || [min_date, Date.today - 1.year].min
    end_date = explicit_end || [max_date, Date.today + 1.year].max

    end_date = start_date if end_date < start_date

    [start_date, end_date]
  end

  def calendar_range_bounds(current_date, view_mode)
    view = view_mode.presence || "month"
    case view
    when "week"
      [current_date.beginning_of_week, current_date.end_of_week]
    when "day"
      [current_date, current_date]
    else
      start_date = current_date.beginning_of_month.beginning_of_week(:sunday)
      end_date = current_date.end_of_month.end_of_week(:sunday)
      [start_date, end_date]
    end
  end

  def sort_occurrences(events)
    case params[:sort]
    when "starts_at_desc"
      events.sort_by(&:starts_at).reverse
    when "title_asc"
      events.sort_by { |event| event.title.to_s.downcase }
    when "title_desc"
      events.sort_by { |event| event.title.to_s.downcase }.reverse
    else
      direction = params[:filter] == "past" ? :desc : :asc
      sorted = events.sort_by(&:starts_at)
      direction == :desc ? sorted.reverse : sorted
    end
  end
end

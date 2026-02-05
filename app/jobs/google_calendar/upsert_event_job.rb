module GoogleCalendar
  class UpsertEventJob < ApplicationJob
    queue_as :default

    def perform(event_id)
      event = Event.find_by(id: event_id)
      return if event.blank?
      return unless event.sync_to_google?

      connection = event.couple.google_calendar_connection
      return if connection.blank? || connection.calendar_id.blank?

      SyncService.new(connection).upsert_event(event)
    rescue RequestError => e
      event.update_columns(
        google_sync_status: "error",
        google_sync_error: e.message
      )
    end
  end
end

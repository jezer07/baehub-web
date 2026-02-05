module GoogleCalendar
  class DeleteEventJob < ApplicationJob
    queue_as :default

    def perform(google_event_id, couple_id)
      return if google_event_id.blank?

      couple = Couple.find_by(id: couple_id)
      return if couple.blank?

      connection = couple.google_calendar_connection
      return if connection.blank? || connection.calendar_id.blank?

      SyncService.new(connection).delete_event(google_event_id)
    end
  end
end

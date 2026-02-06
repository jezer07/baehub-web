module GoogleCalendar
  class PullChangesJob < ApplicationJob
    queue_as :default

    def perform(connection_id)
      connection = GoogleCalendarConnection.find_by(id: connection_id)
      return if connection.blank? || connection.calendar_id.blank?

      sync_service = SyncService.new(connection)
      sync_service.pull_changes
      sync_service.ensure_watch!
    end
  end
end

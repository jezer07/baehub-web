module GoogleCalendar
  class InitialSyncJob < ApplicationJob
    queue_as :default

    def perform(connection_id)
      connection = GoogleCalendarConnection.find_by(id: connection_id)
      return if connection.blank? || connection.calendar_id.blank?

      SyncService.new(connection).initial_sync!
    end
  end
end

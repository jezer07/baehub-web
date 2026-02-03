module GoogleCalendar
  class RenewWatchJob < ApplicationJob
    queue_as :default

    def perform
      GoogleCalendarConnection.where.not(calendar_id: nil).find_each do |connection|
        SyncService.new(connection).ensure_watch!
      rescue RequestError
        next
      end
    end
  end
end

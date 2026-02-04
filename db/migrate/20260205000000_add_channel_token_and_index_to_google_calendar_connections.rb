class AddChannelTokenAndIndexToGoogleCalendarConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :google_calendar_connections, :channel_token, :string
    add_index :google_calendar_connections, :channel_id
  end
end

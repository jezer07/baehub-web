class CreateGoogleCalendarConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :google_calendar_connections do |t|
      t.references :couple, null: false, foreign_key: true, index: { unique: true }
      t.references :user, null: false, foreign_key: true
      t.string :calendar_id
      t.string :calendar_summary
      t.string :access_token
      t.string :refresh_token
      t.datetime :expires_at
      t.string :sync_token
      t.string :channel_id
      t.string :channel_resource_id
      t.datetime :channel_expires_at
      t.datetime :last_synced_at

      t.timestamps
    end
  end
end

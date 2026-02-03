class AddGoogleSyncFieldsToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :sync_to_google, :boolean, null: false, default: false
    add_column :events, :google_event_id, :string
    add_column :events, :google_event_etag, :string
    add_column :events, :google_event_updated_at, :datetime
    add_column :events, :google_last_synced_at, :datetime
    add_column :events, :google_sync_status, :string
    add_column :events, :google_sync_error, :text

    add_index :events, [ :couple_id, :google_event_id ], unique: true
  end
end

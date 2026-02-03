# Google Calendar Sync Integration

This document outlines the requirements and implementation guide for bidirectional Google Calendar synchronization with BaeHub.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Google Cloud Console Setup](#google-cloud-console-setup)
4. [OAuth2 Credentials Generation](#oauth2-credentials-generation)
5. [Required API Scopes](#required-api-scopes)
6. [Technical Implementation](#technical-implementation)
7. [Database Changes](#database-changes)
8. [Sync Strategy](#sync-strategy)
9. [Webhook Setup (Push Notifications)](#webhook-setup-push-notifications)
10. [Security Considerations](#security-considerations)

---

## Overview

### What We're Building

A bidirectional sync between BaeHub's calendar and Google Calendar that:

- **Imports** all events from a user's Google Calendar into BaeHub
- **Exports** events created in BaeHub to Google Calendar
- **Syncs updates** - changes made in either system reflect in the other
- **Syncs deletions** - removed events are deleted from both systems
- **Real-time updates** via webhooks (push notifications)

### Architecture

```
┌─────────────────┐                    ┌─────────────────┐
│                 │  OAuth2 + REST     │                 │
│     BaeHub      │ ◄───────────────►  │ Google Calendar │
│    (Rails 8)    │                    │      API        │
│                 │  Webhooks (Push)   │                 │
└─────────────────┘ ◄────────────────  └─────────────────┘
        │
        ▼
  ┌─────────────┐
  │ solid_queue │  (Background sync jobs)
  └─────────────┘
```

---

## Prerequisites

### Required Accounts & Access

1. **Google Cloud Platform Account** - Free tier is sufficient
2. **Google Workspace or Personal Gmail Account** - For testing
3. **Production Domain with HTTPS** - Required for OAuth callbacks and webhooks

### Required Ruby Gems

Add these to your `Gemfile`:

```ruby
# Google OAuth2 authentication
gem 'omniauth-google-oauth2'
gem 'omniauth-rails_csrf_protection'

# Google Calendar API client
gem 'google-apis-calendar_v3'
```

### Environment Variables Needed

```bash
# .env
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret
GOOGLE_CALENDAR_WEBHOOK_URL=https://yourdomain.com/webhooks/google_calendar
```

---

## Google Cloud Console Setup

### Step 1: Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click the project dropdown at the top → **New Project**
3. Enter project details:
   - **Project name**: `BaeHub Calendar Sync` (or your preferred name)
   - **Organization**: Leave as default or select your org
4. Click **Create**
5. Wait for project creation, then select it from the dropdown

### Step 2: Enable the Google Calendar API

1. In your project, go to **APIs & Services** → **Library**
2. Search for "Google Calendar API"
3. Click on **Google Calendar API**
4. Click **Enable**

### Step 3: Configure OAuth Consent Screen

1. Go to **APIs & Services** → **OAuth consent screen**
2. Select **User Type**:
   - **Internal**: Only for Google Workspace users in your org
   - **External**: For any Google account (choose this for public apps)
3. Click **Create**

4. Fill in the **App Information**:
   - **App name**: `BaeHub`
   - **User support email**: Your email
   - **App logo**: Optional (upload your logo)

5. Fill in **App domain** (required for production):
   - **Application home page**: `https://baehubapp.com`
   - **Application privacy policy link**: `https://baehubapp.com/privacy`
   - **Application terms of service link**: `https://baehubapp.com/terms`

6. **Developer contact information**: Add your email

7. Click **Save and Continue**

### Step 4: Add Scopes

1. Click **Add or Remove Scopes**
2. Search and select these scopes:
   - `https://www.googleapis.com/auth/calendar` - Full access to calendars
   - `https://www.googleapis.com/auth/calendar.events` - Read/write events
   - `https://www.googleapis.com/auth/userinfo.email` - User email
   - `https://www.googleapis.com/auth/userinfo.profile` - User profile info

3. Click **Update** → **Save and Continue**

### Step 5: Add Test Users (For Development)

While your app is in "Testing" status:

1. Click **Add Users**
2. Enter email addresses of test accounts
3. Click **Save and Continue**
4. Review summary and click **Back to Dashboard**

> **Note**: Apps in "Testing" status can only be used by added test users. For production, you'll need to go through Google's verification process.

---

## OAuth2 Credentials Generation

### Step 1: Create OAuth Client ID

1. Go to **APIs & Services** → **Credentials**
2. Click **+ Create Credentials** → **OAuth client ID**
3. Select **Application type**: `Web application`
4. Enter a **Name**: `BaeHub Web Client`

### Step 2: Configure Authorized URIs

**Authorized JavaScript origins** (for frontend OAuth):
```
http://localhost:3000
https://baehubapp.com
```

**Authorized redirect URIs** (OAuth callbacks):
```
http://localhost:3000/users/auth/google_oauth2/callback
https://baehubapp.com/users/auth/google_oauth2/callback
```

### Step 3: Save Credentials

1. Click **Create**
2. A dialog shows your credentials:
   - **Client ID**: `123456789-abc123.apps.googleusercontent.com`
   - **Client Secret**: `GOCSPX-xxxxxxxxxxxxxxxx`
3. Click **Download JSON** to save credentials securely
4. Click **OK**

### Step 4: Store Credentials Securely

Add to your `.env` file (never commit this):

```bash
GOOGLE_CLIENT_ID=123456789-abc123.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-xxxxxxxxxxxxxxxx
```

Add to Rails credentials (recommended for production):

```bash
EDITOR="code --wait" bin/rails credentials:edit
```

```yaml
google:
  client_id: 123456789-abc123.apps.googleusercontent.com
  client_secret: GOCSPX-xxxxxxxxxxxxxxxx
```

---

## Required API Scopes

### Recommended Scopes

| Scope | Purpose | Sensitivity |
|-------|---------|-------------|
| `calendar` | Full read/write access to calendars | Sensitive |
| `calendar.events` | Read/write access to events only | Sensitive |
| `userinfo.email` | Access user's email address | Non-sensitive |
| `userinfo.profile` | Access user's basic profile | Non-sensitive |

### Scope URLs

```ruby
# config/initializers/omniauth.rb
GOOGLE_CALENDAR_SCOPES = [
  'https://www.googleapis.com/auth/calendar',
  'https://www.googleapis.com/auth/calendar.events',
  'https://www.googleapis.com/auth/userinfo.email',
  'https://www.googleapis.com/auth/userinfo.profile'
].freeze
```

### Minimal Scope Option

For read-only sync (import only):

```ruby
GOOGLE_CALENDAR_SCOPES = [
  'https://www.googleapis.com/auth/calendar.readonly',
  'https://www.googleapis.com/auth/userinfo.email'
].freeze
```

---

## Technical Implementation

### 1. OmniAuth Configuration

Create `config/initializers/omniauth.rb`:

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    Rails.application.credentials.dig(:google, :client_id) || ENV['GOOGLE_CLIENT_ID'],
    Rails.application.credentials.dig(:google, :client_secret) || ENV['GOOGLE_CLIENT_SECRET'],
    {
      scope: 'email,profile,calendar,calendar.events',
      access_type: 'offline',      # Required for refresh tokens
      prompt: 'consent',           # Force consent to get refresh token
      include_granted_scopes: true
    }
end

OmniAuth.config.allowed_request_methods = [:post, :get]
```

### 2. Devise OmniAuth Integration

Update `app/models/user.rb`:

```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable,
         :rememberable, :validatable, :confirmable, :trackable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
      user.name = auth.info.name
    end
  end

  def google_oauth_token_valid?
    google_token_expires_at.present? && google_token_expires_at > Time.current
  end

  def refresh_google_token!
    return unless google_refresh_token.present?

    client = OAuth2::Client.new(
      Rails.application.credentials.dig(:google, :client_id),
      Rails.application.credentials.dig(:google, :client_secret),
      site: 'https://oauth2.googleapis.com',
      token_url: '/token'
    )

    token = OAuth2::AccessToken.from_hash(client, refresh_token: google_refresh_token)
    new_token = token.refresh!

    update!(
      google_access_token: new_token.token,
      google_token_expires_at: Time.at(new_token.expires_at)
    )
  end
end
```

### 3. OmniAuth Callbacks Controller

Create `app/controllers/users/omniauth_callbacks_controller.rb`:

```ruby
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    auth = request.env['omniauth.auth']
    @user = current_user || User.from_omniauth(auth)

    if @user.persisted?
      # Store OAuth tokens for calendar sync
      @user.update!(
        google_uid: auth.uid,
        google_access_token: auth.credentials.token,
        google_refresh_token: auth.credentials.refresh_token,
        google_token_expires_at: Time.at(auth.credentials.expires_at),
        google_calendar_sync_enabled: true
      )

      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: 'Google') if is_navigational_format?
    else
      session['devise.google_data'] = auth.except(:extra)
      redirect_to new_user_registration_url, alert: 'Could not authenticate with Google'
    end
  end

  def failure
    redirect_to root_path, alert: 'Google authentication failed'
  end
end
```

### 4. Google Calendar Service

Create `app/services/google_calendar_service.rb`:

```ruby
require 'google/apis/calendar_v3'

class GoogleCalendarService
  CALENDAR_ID = 'primary'

  def initialize(user)
    @user = user
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.authorization = build_authorization
  end

  # Fetch all events from Google Calendar
  def fetch_events(time_min: 1.year.ago, time_max: 1.year.from_now)
    ensure_valid_token!

    @service.list_events(
      CALENDAR_ID,
      single_events: true,
      order_by: 'startTime',
      time_min: time_min.iso8601,
      time_max: time_max.iso8601
    ).items
  end

  # Create event in Google Calendar
  def create_event(event)
    ensure_valid_token!

    google_event = build_google_event(event)
    result = @service.insert_event(CALENDAR_ID, google_event)
    result.id
  end

  # Update event in Google Calendar
  def update_event(event)
    ensure_valid_token!
    return unless event.google_event_id.present?

    google_event = build_google_event(event)
    @service.update_event(CALENDAR_ID, event.google_event_id, google_event)
  end

  # Delete event from Google Calendar
  def delete_event(google_event_id)
    ensure_valid_token!
    return unless google_event_id.present?

    @service.delete_event(CALENDAR_ID, google_event_id)
  rescue Google::Apis::ClientError => e
    Rails.logger.warn "Failed to delete Google event: #{e.message}"
  end

  # Watch for changes (webhook setup)
  def watch_events(webhook_url, channel_id: SecureRandom.uuid)
    ensure_valid_token!

    channel = Google::Apis::CalendarV3::Channel.new(
      id: channel_id,
      type: 'web_hook',
      address: webhook_url,
      expiration: 7.days.from_now.to_i * 1000  # Milliseconds
    )

    @service.watch_event(CALENDAR_ID, channel)
  end

  private

  def build_authorization
    credentials = Google::Auth::UserRefreshCredentials.new(
      client_id: Rails.application.credentials.dig(:google, :client_id),
      client_secret: Rails.application.credentials.dig(:google, :client_secret),
      scope: ['https://www.googleapis.com/auth/calendar'],
      access_token: @user.google_access_token,
      refresh_token: @user.google_refresh_token,
      expires_at: @user.google_token_expires_at
    )
    credentials
  end

  def ensure_valid_token!
    unless @user.google_oauth_token_valid?
      @user.refresh_google_token!
      @service.authorization = build_authorization
    end
  end

  def build_google_event(event)
    Google::Apis::CalendarV3::Event.new(
      summary: event.title,
      description: event.description,
      start: event_datetime(event.starts_at, event.all_day),
      end: event_datetime(event.ends_at || event.starts_at + 1.hour, event.all_day),
      recurrence: event.recurrence_rule.present? ? [convert_recurrence(event.recurrence_rule)] : nil
    )
  end

  def event_datetime(time, all_day)
    if all_day
      Google::Apis::CalendarV3::EventDateTime.new(date: time.to_date.iso8601)
    else
      Google::Apis::CalendarV3::EventDateTime.new(
        date_time: time.iso8601,
        time_zone: @user.timezone || 'UTC'
      )
    end
  end

  def convert_recurrence(rule)
    # Convert BaeHub recurrence format to RRULE
    # BaeHub format: "frequency:interval:end_date" (e.g., "daily:1:2025-12-31")
    frequency, interval, end_date = rule.split(':')

    rrule = "RRULE:FREQ=#{frequency.upcase}"
    rrule += ";INTERVAL=#{interval}" if interval.to_i > 1
    rrule += ";UNTIL=#{end_date.gsub('-', '')}T235959Z" if end_date.present?
    rrule
  end
end
```

### 5. Sync Job

Create `app/jobs/google_calendar_sync_job.rb`:

```ruby
class GoogleCalendarSyncJob < ApplicationJob
  queue_as :default

  def perform(user_id, sync_type: :full)
    user = User.find(user_id)
    return unless user.google_calendar_sync_enabled?

    service = GoogleCalendarService.new(user)
    sync_service = GoogleCalendarSyncService.new(user, service)

    case sync_type
    when :full
      sync_service.full_sync
    when :incremental
      sync_service.incremental_sync
    when :export
      sync_service.export_new_events
    end
  rescue Google::Apis::AuthorizationError => e
    user.update!(google_calendar_sync_enabled: false)
    Rails.logger.error "Google Calendar auth failed for user #{user_id}: #{e.message}"
  end
end
```

### 6. Sync Service

Create `app/services/google_calendar_sync_service.rb`:

```ruby
class GoogleCalendarSyncService
  def initialize(user, google_service)
    @user = user
    @couple = user.couple
    @google_service = google_service
  end

  def full_sync
    import_from_google
    export_to_google
    @user.update!(google_calendar_last_synced_at: Time.current)
  end

  def incremental_sync
    # Only sync events changed since last sync
    time_min = @user.google_calendar_last_synced_at || 1.year.ago
    import_from_google(time_min: time_min)
    export_new_events
    @user.update!(google_calendar_last_synced_at: Time.current)
  end

  def import_from_google(time_min: 1.year.ago)
    google_events = @google_service.fetch_events(time_min: time_min)

    google_events.each do |google_event|
      import_single_event(google_event)
    end
  end

  def export_to_google
    # Export events that don't have a google_event_id
    @couple.events.where(google_event_id: nil).find_each do |event|
      export_single_event(event)
    end
  end

  def export_new_events
    # Export events created since last sync
    @couple.events
      .where(google_event_id: nil)
      .where('created_at > ?', @user.google_calendar_last_synced_at || 1.year.ago)
      .find_each do |event|
        export_single_event(event)
      end
  end

  private

  def import_single_event(google_event)
    existing = @couple.events.find_by(google_event_id: google_event.id)

    if existing
      update_event_from_google(existing, google_event)
    else
      create_event_from_google(google_event)
    end
  end

  def create_event_from_google(google_event)
    starts_at = parse_google_datetime(google_event.start)
    ends_at = parse_google_datetime(google_event.end)
    all_day = google_event.start.date.present?

    @couple.events.create!(
      title: google_event.summary || 'Untitled Event',
      description: google_event.description,
      starts_at: starts_at,
      ends_at: ends_at,
      all_day: all_day,
      google_event_id: google_event.id,
      google_calendar_id: 'primary',
      creator: @user,
      synced_from_google: true
    )
  end

  def update_event_from_google(event, google_event)
    starts_at = parse_google_datetime(google_event.start)
    ends_at = parse_google_datetime(google_event.end)

    event.update!(
      title: google_event.summary || 'Untitled Event',
      description: google_event.description,
      starts_at: starts_at,
      ends_at: ends_at,
      all_day: google_event.start.date.present?,
      google_updated_at: Time.current
    )
  end

  def export_single_event(event)
    google_event_id = @google_service.create_event(event)
    event.update!(google_event_id: google_event_id, google_calendar_id: 'primary')
  rescue Google::Apis::ClientError => e
    Rails.logger.error "Failed to export event #{event.id}: #{e.message}"
  end

  def parse_google_datetime(event_time)
    if event_time.date
      Date.parse(event_time.date).beginning_of_day
    else
      Time.parse(event_time.date_time.to_s)
    end
  end
end
```

---

## Database Changes

### Migration for Users Table

```bash
rails generate migration AddGoogleCalendarFieldsToUsers
```

```ruby
class AddGoogleCalendarFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :google_uid, :string
    add_column :users, :google_access_token, :text
    add_column :users, :google_refresh_token, :text
    add_column :users, :google_token_expires_at, :datetime
    add_column :users, :google_calendar_sync_enabled, :boolean, default: false
    add_column :users, :google_calendar_last_synced_at, :datetime
    add_column :users, :google_calendar_channel_id, :string
    add_column :users, :google_calendar_channel_expiration, :datetime

    add_index :users, :google_uid
  end
end
```

### Migration for Events Table

```bash
rails generate migration AddGoogleCalendarFieldsToEvents
```

```ruby
class AddGoogleCalendarFieldsToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :google_event_id, :string
    add_column :events, :google_calendar_id, :string
    add_column :events, :google_updated_at, :datetime
    add_column :events, :synced_from_google, :boolean, default: false

    add_index :events, :google_event_id
    add_index :events, [:couple_id, :google_event_id]
  end
end
```

### Migration for Calendar Sync Logs (Optional)

```bash
rails generate migration CreateGoogleCalendarSyncLogs
```

```ruby
class CreateGoogleCalendarSyncLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :google_calendar_sync_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :sync_type, null: false  # full, incremental, webhook
      t.string :status, null: false     # started, completed, failed
      t.integer :events_imported, default: 0
      t.integer :events_exported, default: 0
      t.integer :events_updated, default: 0
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
  end
end
```

---

## Sync Strategy

### Bidirectional Sync Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    SYNC DECISION FLOW                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Event Created in BaeHub                                     │
│  └── Export to Google → Store google_event_id                │
│                                                              │
│  Event Created in Google                                     │
│  └── Import to BaeHub → Store google_event_id                │
│                         └── Mark synced_from_google: true    │
│                                                              │
│  Event Updated in BaeHub                                     │
│  └── If google_event_id exists → Update in Google            │
│                                                              │
│  Event Updated in Google (via webhook)                       │
│  └── Find by google_event_id → Update in BaeHub              │
│                                                              │
│  Event Deleted in BaeHub                                     │
│  └── If google_event_id exists → Delete from Google          │
│                                                              │
│  Event Deleted in Google (via webhook)                       │
│  └── Find by google_event_id → Delete from BaeHub            │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Conflict Resolution

When the same event is modified in both systems:

1. **Last-write-wins**: Compare `updated_at` timestamps
2. **Google-wins**: Always prefer Google's version (simpler)
3. **User-choice**: Prompt user to resolve conflicts (complex)

Recommended: Start with **Google-wins** for simplicity.

### Sync Triggers

| Trigger | Action |
|---------|--------|
| User connects Google account | Full sync |
| User creates event in BaeHub | Export single event |
| User updates event in BaeHub | Update in Google |
| User deletes event in BaeHub | Delete from Google |
| Webhook received from Google | Incremental sync |
| Scheduled job (hourly) | Incremental sync |
| User manually triggers sync | Full sync |

---

## Webhook Setup (Push Notifications)

### Why Webhooks?

Instead of polling Google Calendar for changes, webhooks push updates to your app in real-time.

### Webhook Controller

Create `app/controllers/webhooks/google_calendar_controller.rb`:

```ruby
module Webhooks
  class GoogleCalendarController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate_user!

    def receive
      channel_id = request.headers['X-Goog-Channel-ID']
      resource_state = request.headers['X-Goog-Resource-State']

      case resource_state
      when 'sync'
        # Initial sync confirmation - ignore
        head :ok
      when 'exists'
        # Events changed - trigger incremental sync
        user = User.find_by(google_calendar_channel_id: channel_id)
        GoogleCalendarSyncJob.perform_later(user.id, sync_type: :incremental) if user
        head :ok
      else
        head :ok
      end
    end
  end
end
```

### Routes

```ruby
# config/routes.rb
namespace :webhooks do
  post 'google_calendar', to: 'google_calendar#receive'
end
```

### Setting Up Watch Channel

```ruby
# Call this after user connects Google Calendar
def setup_google_calendar_watch(user)
  service = GoogleCalendarService.new(user)
  webhook_url = "#{Rails.application.credentials.dig(:app, :host)}/webhooks/google_calendar"

  channel = service.watch_events(webhook_url)

  user.update!(
    google_calendar_channel_id: channel.id,
    google_calendar_channel_expiration: Time.at(channel.expiration / 1000)
  )
end
```

### Renewing Watch Channels

Channels expire after ~7 days. Create a job to renew:

```ruby
# app/jobs/renew_google_calendar_watches_job.rb
class RenewGoogleCalendarWatchesJob < ApplicationJob
  queue_as :default

  def perform
    User.where(google_calendar_sync_enabled: true)
        .where('google_calendar_channel_expiration < ?', 1.day.from_now)
        .find_each do |user|
          setup_google_calendar_watch(user)
        end
  end
end
```

Schedule this job to run daily using `solid_queue`.

---

## Security Considerations

### Token Storage

- **Encrypt tokens at rest** using Rails encrypted credentials or `attr_encrypted`
- **Never log tokens** - ensure they're filtered from logs
- **Use short-lived access tokens** with refresh token rotation

```ruby
# config/initializers/filter_parameter_logging.rb
Rails.application.config.filter_parameters += [
  :google_access_token,
  :google_refresh_token
]
```

### OAuth Best Practices

1. Always use HTTPS in production
2. Validate OAuth state parameter to prevent CSRF
3. Request minimum necessary scopes
4. Handle token revocation gracefully

### Webhook Security

1. Verify webhook requests using the `X-Goog-Channel-Token` header
2. Use HTTPS for webhook endpoints
3. Implement rate limiting

```ruby
# Enhanced webhook verification
def receive
  expected_token = Rails.application.credentials.dig(:google, :webhook_token)
  received_token = request.headers['X-Goog-Channel-Token']

  unless ActiveSupport::SecurityUtils.secure_compare(expected_token.to_s, received_token.to_s)
    head :unauthorized
    return
  end

  # ... process webhook
end
```

---

## Quick Start Checklist

- [ ] Create Google Cloud Project
- [ ] Enable Google Calendar API
- [ ] Configure OAuth Consent Screen
- [ ] Create OAuth 2.0 Credentials
- [ ] Add credentials to `.env` or Rails credentials
- [ ] Add gems to Gemfile and run `bundle install`
- [ ] Run database migrations
- [ ] Configure OmniAuth initializer
- [ ] Add OmniAuth callbacks controller
- [ ] Update Devise routes
- [ ] Create GoogleCalendarService
- [ ] Create sync jobs
- [ ] Add webhook endpoint
- [ ] Add UI for connecting Google Calendar
- [ ] Test with test users
- [ ] Submit for Google verification (production)

---

## Appendix: Useful Links

- [Google Calendar API Documentation](https://developers.google.com/calendar/api/v3/reference)
- [Google OAuth 2.0 Documentation](https://developers.google.com/identity/protocols/oauth2)
- [OAuth Consent Screen Configuration](https://support.google.com/googleapi/answer/6158849)
- [Google Calendar API Scopes](https://developers.google.com/workspace/calendar/api/auth)
- [OmniAuth Google OAuth2 Gem](https://github.com/zquestz/omniauth-google-oauth2)
- [Google APIs Ruby Client](https://github.com/googleapis/google-api-ruby-client)

---

## Google Verification (For Production)

If your app will be used by users outside your organization, you must complete Google's verification process:

1. Go to **OAuth consent screen** → **Publish App**
2. Click **Prepare for Verification**
3. Provide:
   - Detailed app description
   - Link to privacy policy
   - Link to terms of service
   - YouTube video demonstrating OAuth flow
   - Justification for each sensitive scope
4. Submit for review (can take 4-6 weeks)

Until verified, your app will show a "This app isn't verified" warning to users.

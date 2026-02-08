# Rails Native Execution Plan (BaeHub)

## 1. Purpose

This document is an **implementation playbook** for shipping BaeHub as a Rails Native app (Hotwire Native iOS + Android) while keeping the existing Rails web app as the source of truth.

It is written for an execution agent (human or AI) to follow end-to-end with minimal ambiguity.

---

## 2. Execution Contract

1. Preserve existing web behavior unless a step explicitly says otherwise.
2. Prefer incremental, reviewable commits (one workstream at a time).
3. Keep production-safe defaults: feature flags, backwards compatibility, and fallbacks.
4. Do not rewrite the app into JSON API + Flutter as part of this plan.
5. Do not block mobile launch on optional enhancements.

---

## 3. Current Baseline (Repository Snapshot)

Path: `/Users/jezer/projects/baehub-web`

- Rails: `8.1.x` (`Gemfile`)
- Turbo/Stimulus/importmap already present (`config/importmap.rb`)
- Devise session auth present (`config/routes.rb`, `app/models/user.rb`)
- Web-first app with server-rendered ERB + Turbo Stream:
  - ~58 ERB templates under `app/views`
  - 7 Turbo stream templates
  - 13 controllers
- Existing Google Calendar OAuth flow is web/session-oriented:
  - `app/controllers/google_calendar_connections_controller.rb`
- Existing mobile/PWA hints exist but are not the native wrapper solution:
  - `app/views/pwa/*`

Implication: this codebase is an excellent candidate for Rails Native with moderate backend adaptation, and a poor candidate for immediate full-native Flutter rewrite.

---

## 4. Target State

### 4.1 MVP (must ship)

1. iOS and Android wrappers load the Rails app URL via Hotwire Native.
2. Authentication works with current Devise session flow.
3. Path configuration controls mobile navigation behavior (push vs modal).
4. CRUD flows feel native (proper stack behavior after create/update/destroy).
5. External links/OAuth are handled safely.
6. Regression-free web behavior remains intact.

### 4.2 Post-MVP (strongly recommended)

1. Bridge component(s) for native polish (e.g., native top-bar actions).
2. Native-tailored layout polish (reduced web nav/footer noise in wrapper).
3. Mobile observability and release automation.

---

## 5. Scope and Non-Goals

### In Scope

- Rails changes required for native behavior.
- iOS Hotwire Native app bootstrap.
- Android Hotwire Native app bootstrap.
- QA, rollout, and release checklist.

### Out of Scope

- Full API-first rewrite.
- Flutter client implementation.
- Deep redesign of product UX.
- In-app purchases implementation (separate workstream with StoreKit/Play Billing + Rails entitlement endpoints).

---

## 6. Architecture Decisions (Lock Before Coding)

Before implementation begins, lock these decisions in a short ADR note:

1. **Mobile app host/domain** (e.g., `https://accounts.baehubapp.com`).
2. **Native app ids**:
   - iOS bundle id
   - Android applicationId
3. **Repo strategy**:
   - Option A: native apps in separate repos (recommended)
   - Option B: mono-repo under `/mobile/ios`, `/mobile/android`
4. **Google Calendar in native v1**:
   - Option A: defer connection UX in native and deep-link user to web
   - Option B: implement native-safe OAuth callback strategy in v1

Do not start feature code until these are agreed.

---

## 7. Workstream Plan

## WS0 - Branching, Tooling, and Safety

### Tasks

1. Create branch `codex/rails-native-mvp`.
2. Verify app boots locally:
   - `bin/setup --skip-server`
   - `bin/dev`
3. Capture baseline tests:
   - `bin/rails test`
   - optionally `bin/rails test:system`

### Exit Criteria

- Branch created.
- Baseline app runs.
- Baseline test results recorded.

---

## WS1 - Rails: Native-Aware Server Behavior

### WS1.1 Add path-configuration endpoints

Create platform-specific remote config endpoints that native apps fetch.

### Files to add

1. `app/controllers/configurations_controller.rb`
2. `app/views/configurations/ios_v1.json.erb`
3. `app/views/configurations/android_v1.json.erb`

### Files to edit

1. `config/routes.rb`

### Route additions

- `get "/configurations/ios_v1", to: "configurations#ios_v1", defaults: { format: :json }`
- `get "/configurations/android_v1", to: "configurations#android_v1", defaults: { format: :json }`

### JSON behavior requirements

#### iOS config minimum

- default rule for all pages:
  - `context: "default"`
  - `pull_to_refresh_enabled: true`
- modal rules for form pages:
  - `/tasks/new$`
  - `/tasks/\\d+/edit$`
  - `/events/new$`
  - `/events/\\d+/edit$`
  - `/expenses/new$`
  - `/expenses/\\d+/edit$`
  - `/settlements/new$`
  - `/settlements/\\d+/edit$`
  - `/pairing/new$`
  - with:
    - `context: "modal"`
    - `pull_to_refresh_enabled: false`

#### Android config minimum

- same pattern logic as iOS, but each rule must include `uri`:
  - default screens: `hotwire://fragment/web`
  - modal screens: `hotwire://fragment/web/modal/sheet`

### Exit Criteria

- both endpoints return valid JSON.
- path configs are deterministic and versioned (`*_v1` naming).

---

### WS1.2 Add mobile-aware layout behavior

Goal: avoid redundant desktop chrome inside native wrappers.

### Files to edit

1. `app/views/layouts/application.html.erb`

### Changes

1. Wrap heavy desktop navigation/footer in conditional:
   - render full nav/footer when `!hotwire_native_app?`
   - render compact/mobile-safe wrapper when `hotwire_native_app?`
2. Keep flash rendering and main content in both modes.
3. Preserve web appearance for regular browser user agents.

### Exit Criteria

- Native UA sees cleaner shell.
- Browser UA unchanged.

---

### WS1.3 Server-driven native navigation corrections

Use Turbo Native historical redirects in mutating actions so stack behavior is native.

### High-priority controllers

1. `app/controllers/tasks_controller.rb`
2. `app/controllers/events_controller.rb`
3. `app/controllers/expenses_controller.rb`
4. `app/controllers/settlements_controller.rb`
5. `app/controllers/settings_controller.rb`
6. `app/controllers/pairings_controller.rb`
7. `app/controllers/invitations_controller.rb`

### Pattern to apply

Where action currently does `redirect_to ...` after successful mutation:

- if flow is modal/new/edit style and should close:
  - use `recede_or_redirect_to(...)`
- if flow should stay on current screen and just ignore navigation:
  - use `resume_or_redirect_to(...)`
- if flow should reload current screen:
  - use `refresh_or_redirect_to(...)`

### Recommended action mapping (initial)

1. `create` from `/new` forms -> `recede_or_redirect_to(index_or_show_path)`
2. `update` from `/edit` forms -> `recede_or_redirect_to(show_or_index_path)`
3. `destroy` from detail/list -> usually `recede_or_redirect_to(index_path)` if deletion occurs on pushed detail screen
4. settings updates -> `refresh_or_redirect_to(settings_path)`

### Important

- Keep existing `format.turbo_stream` branches where present.
- Do not break non-native behavior; these helpers already fallback to normal redirects outside native user agents.

### Exit Criteria

- iOS/Android back stack behaves correctly after CRUD.
- Browser behavior remains unchanged.

---

### WS1.4 Native detection helper (optional hardening)

Turbo includes `hotwire_native_app?` automatically. Optionally centralize behavior:

### File to edit

1. `app/controllers/application_controller.rb`

### Optional additions

1. helper method `native_app?` aliasing `hotwire_native_app?`
2. shared redirection helpers if needed for code clarity

### Exit Criteria

- no duplication of user-agent checks across controllers/views.

---

### WS1.5 Google OAuth strategy for native (critical risk item)

Current flow uses session-bound state and redirects to Google. Native wrappers can make this fragile if cookie jars differ.

Implement one of the following explicitly:

#### Option A (recommended for MVP speed)

1. Disable Google connect/disconnect UI in native wrapper with explanatory text.
2. Provide “Open in browser” fallback for Google connect.
3. Keep web OAuth untouched.

#### Option B (full native OAuth in v1)

1. Add native-safe OAuth state persistence (DB-backed nonce, not session-only).
2. Add callback handling robust to external user-agent return.
3. Configure universal links/app links correctly.

### Files impacted (if Option B)

1. `app/controllers/google_calendar_connections_controller.rb`
2. new model/migration for OAuth state nonce
3. path config/deep-link support docs

### Exit Criteria

- No broken Google connect path in native app.
- Explicit product decision documented.

---

### WS1.6 Install Hotwire Native Bridge JS (post-MVP but recommended)

### Files to edit

1. `config/importmap.rb`
2. `app/javascript/application.js`
3. potentially new controller files in `app/javascript/controllers`

### Commands

- `bin/importmap pin @hotwired/hotwire-native-bridge`

### Minimum implementation

1. JS bridge installed and imported.
2. no-op component registration scaffolded.
3. CSS hide bridged web-only UI when native component is present.

### Exit Criteria

- Bridge package loads without JS errors.

---

### WS1.7 Concrete code templates (use as starting point)

Use these as implementation scaffolds to reduce ambiguity.

#### `app/controllers/configurations_controller.rb`

```ruby
class ConfigurationsController < ApplicationController
  def ios_v1
    render :ios_v1, formats: :json
  end

  def android_v1
    render :android_v1, formats: :json
  end
end
```

#### `app/views/configurations/ios_v1.json.erb`

```json
{
  "settings": {},
  "rules": [
    {
      "patterns": [".*"],
      "properties": {
        "context": "default",
        "pull_to_refresh_enabled": true
      }
    },
    {
      "patterns": [
        "/tasks/new$",
        "/tasks/\\d+/edit$",
        "/events/new$",
        "/events/\\d+/edit$",
        "/expenses/new$",
        "/expenses/\\d+/edit$",
        "/settlements/new$",
        "/settlements/\\d+/edit$",
        "/pairing/new$"
      ],
      "properties": {
        "context": "modal",
        "pull_to_refresh_enabled": false
      }
    }
  ]
}
```

#### `app/views/configurations/android_v1.json.erb`

```json
{
  "settings": {},
  "rules": [
    {
      "patterns": [".*"],
      "properties": {
        "context": "default",
        "uri": "hotwire://fragment/web",
        "pull_to_refresh_enabled": true
      }
    },
    {
      "patterns": [
        "/tasks/new$",
        "/tasks/\\d+/edit$",
        "/events/new$",
        "/events/\\d+/edit$",
        "/expenses/new$",
        "/expenses/\\d+/edit$",
        "/settlements/new$",
        "/settlements/\\d+/edit$",
        "/pairing/new$"
      ],
      "properties": {
        "context": "modal",
        "uri": "hotwire://fragment/web/modal/sheet",
        "pull_to_refresh_enabled": false
      }
    }
  ]
}
```

---

### WS1.8 Redirect conversion matrix (controller-action level)

Apply this matrix during WS1.3.

### Must convert first

1. `TasksController#create` -> prefer `recede_or_redirect_to(tasks_path or safe_redirect_target)`
2. `TasksController#update` (HTML branch) -> prefer `recede_or_redirect_to(task_path(@task))`
3. `TasksController#destroy` (HTML branch) -> prefer `recede_or_redirect_to(tasks_path)`
4. `EventsController#create` -> prefer `recede_or_redirect_to(events_path)`
5. `EventsController#update` -> prefer `recede_or_redirect_to(event_path(@event))`
6. `EventsController#destroy` -> prefer `recede_or_redirect_to(events_path)`
7. `ExpensesController#create` -> prefer `recede_or_redirect_to(expenses_path)`
8. `ExpensesController#update` -> prefer `recede_or_redirect_to(expense_path(@expense))`
9. `ExpensesController#destroy` -> prefer `recede_or_redirect_to(expenses_path)`
10. `SettlementsController#create` (HTML branch) -> prefer `recede_or_redirect_to(expenses_path)`
11. `SettlementsController#update` (HTML branch) -> prefer `recede_or_redirect_to(expenses_path)`
12. `SettlementsController#destroy` -> prefer `recede_or_redirect_to(expenses_path)`
13. `SettingsController#update` -> prefer `refresh_or_redirect_to(settings_path)`

### Convert next (secondary)

1. `PairingsController#create` -> evaluate `recede_or_redirect_to(new_pairing_path)` vs existing UX
2. `PairingsController#join` -> evaluate `replace_root`-like behavior via path config or keep standard redirect fallback
3. `InvitationsController#create` and `#destroy` -> keep `redirect_back` for web; for native, ensure back-stack behavior acceptable
4. `EventResponsesController#create` and `#update` HTML branches -> usually `refresh_or_redirect_to(event_path(@event))`
5. guard redirects (`ensure_couple!`, `set_* rescue`) may remain as normal redirects initially

### Rules of thumb during conversion

1. If user just submitted a form and should return to prior screen -> `recede_or_redirect_to`.
2. If current screen should re-request fresh data -> `refresh_or_redirect_to`.
3. If no navigation should happen in native stack but web needs redirect -> `resume_or_redirect_to`.
4. Keep turbo stream behavior unchanged unless it is clearly broken.

---

## WS2 - iOS Native Shell

## WS2.1 Bootstrap app

1. Create iOS app in Xcode (Swift + Storyboard baseline as per Hotwire docs).
2. Add package dependency:
   - `https://github.com/hotwired/hotwire-native-ios`
3. Configure `SceneDelegate` with:
   - `Navigator(configuration: .init(name: "main", startLocation: <APP_URL>))`

## WS2.2 Configure app startup

In `AppDelegate.swift`:

1. Load local + remote path config:
   - local bundled `path-configuration.json`
   - remote `https://<app-domain>/configurations/ios_v1.json`
2. Register bridge components (if implemented).
3. Optional debug logging in debug builds.

## WS2.3 Deep links and associated domains

1. Configure Associated Domains capability:
   - `applinks:<domain>`
2. Ensure `apple-app-site-association` served by backend/domain infra.

## WS2.4 Routing behavior checks

Verify:

1. internal URLs stay in app.
2. external URLs open via native external handler.
3. forms marked modal in path config present modally.

### Exit Criteria

- iOS app can authenticate and use core CRUD flows.

### WS2.5 iOS template snippets

#### `SceneDelegate.swift` starter

```swift
import HotwireNative
import UIKit

let rootURL = URL(string: "https://YOUR_APP_DOMAIN")!

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private let navigator = Navigator(configuration: .init(
        name: "main",
        startLocation: rootURL
    ))

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        window?.rootViewController = navigator.rootViewController
        navigator.start()
    }
}
```

#### `AppDelegate.swift` path config starter

```swift
import HotwireNative
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let localPathConfigURL = Bundle.main.url(forResource: "path-configuration", withExtension: "json")!
        let remotePathConfigURL = URL(string: "https://YOUR_APP_DOMAIN/configurations/ios_v1.json")!

        Hotwire.loadPathConfiguration(from: [
            .file(localPathConfigURL),
            .server(remotePathConfigURL)
        ])

        return true
    }
}
```

---

## WS3 - Android Native Shell

## WS3.1 Bootstrap app

1. Create Android app (Empty Views Activity, API 28+).
2. Add dependencies in module `build.gradle.kts`:
   - `dev.hotwire:core:<latest>`
   - `dev.hotwire:navigation-fragments:<latest>`
3. Add internet permission in manifest.
4. Implement `HotwireActivity` and `NavigatorConfiguration`.

## WS3.2 App-level config

In `Application` subclass:

1. `Hotwire.loadPathConfiguration(...)` with local asset + remote URL:
   - `https://<app-domain>/configurations/android_v1.json`
2. register fragment destinations (including default web fragment).
3. register bridge components if implemented.

## WS3.3 App links

1. Configure intent filters.
2. Host `/.well-known/assetlinks.json` with package + SHA256.

### Exit Criteria

- Android app can authenticate and use core CRUD flows.

### WS3.4 Android template snippets

#### `MainActivity.kt` starter

```kotlin
import android.os.Bundle
import android.view.View
import androidx.activity.enableEdgeToEdge
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.util.applyDefaultImeWindowInsets

class MainActivity : HotwireActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        findViewById<View>(R.id.main_nav_host).applyDefaultImeWindowInsets()
    }

    override fun navigatorConfigurations() = listOf(
        NavigatorConfiguration(
            name = "main",
            startLocation = "https://YOUR_APP_DOMAIN",
            navigatorHostId = R.id.main_nav_host
        )
    )
}
```

#### `Application` config starter

```kotlin
import android.app.Application
import dev.hotwire.navigation.config.PathConfiguration
import dev.hotwire.navigation.Hotwire

class App : Application() {
    override fun onCreate() {
        super.onCreate()

        Hotwire.loadPathConfiguration(
            context = this,
            location = PathConfiguration.Location(
                assetFilePath = "json/configuration.json",
                remoteFileUrl = "https://YOUR_APP_DOMAIN/configurations/android_v1.json"
            )
        )
    }
}
```

---

## WS4 - Testing and Quality Gates

## WS4.1 Rails automated tests

Add/extend integration tests for native-specific behavior.

### Candidate test files

1. `test/controllers/tasks_controller_test.rb`
2. `test/controllers/events_controller_test.rb`
3. `test/controllers/expenses_controller_test.rb`
4. `test/controllers/settlements_controller_test.rb`
5. `test/controllers/settings_controller_test.rb`

### Required assertions

1. Under native UA, mutating actions redirect to historical locations (`/recede_historical_location`, `/refresh_historical_location`, etc.) when expected.
2. Under normal UA, fallback redirects remain unchanged.

Use user-agent header containing `Hotwire Native` for native simulation.

### Example integration test pattern

```ruby
test "native create task recedes instead of regular redirect" do
  sign_in users(:one)

  post tasks_path,
    params: { task: { title: "Native test task", status: "todo", priority: "medium" } },
    headers: { "HTTP_USER_AGENT" => "Hotwire Native iOS" }

  assert_redirected_to turbo_recede_historical_location_url
end
```

```ruby
test "web create task keeps normal redirect" do
  sign_in users(:one)

  post tasks_path,
    params: { task: { title: "Web test task", status: "todo", priority: "medium" } }

  assert_redirected_to tasks_path
end
```

## WS4.2 Manual E2E matrix

Run on iOS + Android:

1. Sign in/out
2. Create/edit/delete task
3. Create/edit/delete event
4. Create/edit/delete expense
5. Create/edit/delete settlement
6. Pairing flows
7. Settings update
8. Flash messages and validation errors
9. Back navigation stack sanity
10. External links behavior
11. Google Calendar connect path (expected behavior per chosen option)

### WS4.2.a Fast smoke checklist script

Execute this exact order on both iOS and Android test builds:

1. Launch app to unauthenticated root.
2. Sign in with an existing user.
3. Open Tasks -> New -> Create -> verify modal closes and list updates.
4. Open Tasks item -> Edit -> Save -> verify expected stack behavior.
5. Delete a task from detail page -> verify return location is sane.
6. Repeat steps 3-5 for Events.
7. Repeat steps 3-5 for Expenses.
8. Repeat steps 3-5 for Settlements.
9. Open Settings -> update value -> verify current screen refresh behavior.
10. Trigger at least one validation error in each domain form and verify flash visibility.
11. Tap an external URL and verify external browser opening behavior.
12. Execute Google Calendar flow and verify expected UX per Option A or Option B.

## WS4.3 CI

Run project CI at least once before merge:

- `bin/ci`

---

## WS5 - Release and Rollout

## WS5.1 Release artifacts

1. iOS: TestFlight build with release notes.
2. Android: Internal testing track build.
3. Rails deploy containing path config endpoints + native-aware behavior.

## WS5.2 Rollout sequence

1. Deploy Rails backend first.
2. Verify config endpoints are reachable in production.
3. Release internal mobile builds.
4. Run smoke tests with real accounts.
5. Promote to wider beta.

## WS5.3 Observability

Track:

1. sign-in success/failure rates
2. 4xx/5xx by controller action
3. redirect loops
4. mobile crash/error telemetry

---

## 8. Execution Order (Do Not Reorder)

Follow this sequence exactly:

1. Lock architecture decisions in Section 6.
2. Complete WS0 baseline and capture test outputs.
3. Implement WS1.1 (configuration endpoints) and verify with `curl`.
4. Implement WS1.2 (layout conditioning) and manually verify browser parity.
5. Implement WS1.3 redirect conversions incrementally:
   - tasks first
   - events second
   - expenses third
   - settlements fourth
   - settings fifth
6. Add WS4.1 tests for each conversion batch before moving to next batch.
7. Resolve WS1.5 OAuth strategy before mobile beta cut.
8. Build iOS shell (WS2) and run WS4.2 checklist.
9. Build Android shell (WS3) and run WS4.2 checklist.
10. Run `bin/ci` on Rails repo and fix all failures.
11. Execute WS5 rollout sequence.

If any step fails, do not continue to next step until fixed.

---

## 9. Detailed Rails File Checklist

## Must Create

1. `app/controllers/configurations_controller.rb`
2. `app/views/configurations/ios_v1.json.erb`
3. `app/views/configurations/android_v1.json.erb`

## Must Edit

1. `config/routes.rb`
2. `app/views/layouts/application.html.erb`
3. `app/controllers/tasks_controller.rb`
4. `app/controllers/events_controller.rb`
5. `app/controllers/expenses_controller.rb`
6. `app/controllers/settlements_controller.rb`
7. `app/controllers/settings_controller.rb`
8. `app/controllers/pairings_controller.rb`
9. `app/controllers/invitations_controller.rb`

## Optional (but recommended)

1. `config/importmap.rb`
2. `app/javascript/application.js`
3. new bridge-related stimulus controllers under `app/javascript/controllers`
4. `app/controllers/application_controller.rb` for shared helpers

---

## 10. Suggested Commit Plan

1. `feat(native): add ios/android path configuration endpoints`
2. `feat(native): add native-aware layout shell`
3. `feat(native): use native historical redirects for CRUD flows`
4. `test(native): add user-agent based redirect tests`
5. `feat(native-bridge): install hotwire native bridge web package` (optional)
6. `docs(native): add mobile setup and release runbook`

---

## 11. Acceptance Criteria (Definition of Done)

All must be true:

1. iOS and Android wrappers load production app URL successfully.
2. Login flow works and session persists across normal app usage.
3. Core CRUD flows do not create broken/duplicate navigation stack entries.
4. Modal/push behavior follows remote path config rules.
5. Native user-agent receives compact layout; browser unchanged.
6. CI passes (`bin/ci`) after Rails changes.
7. Google Calendar path is either:
   - intentionally deferred with clear UX, or
   - fully supported and tested on native.
8. Release checklist executed and signed off.

---

## 12. Risks and Mitigations

### Risk 1: OAuth breakage in native context

- Impact: High
- Mitigation: explicit Option A or Option B (WS1.5), do not leave implicit.

### Risk 2: Redirect loops or broken back-stack

- Impact: High
- Mitigation: convert redirects gradually, test per controller with native UA integration tests.

### Risk 3: Path config drift between app versions

- Impact: Medium
- Mitigation: keep versioned configs (`ios_v1`, `android_v1`), introduce `v2` for breaking changes.

### Risk 4: Web regression from native layout conditionals

- Impact: Medium
- Mitigation: browser snapshot/manual checks + existing controller/system tests.

---

## 13. Commands Cheat Sheet

### Rails

```bash
cd /Users/jezer/projects/baehub-web
bin/setup --skip-server
bin/dev
bin/rails routes | rg configurations
bin/rails test
bin/ci
```

### Bridge install (optional)

```bash
cd /Users/jezer/projects/baehub-web
bin/importmap pin @hotwired/hotwire-native-bridge
```

### Verify Turbo Native historical routes exist

```bash
cd /Users/jezer/projects/baehub-web
bin/rails routes | rg "recede_historical_location|resume_historical_location|refresh_historical_location"
```

---

## 14. References (Authoritative)

1. Hotwire Native iOS getting started  
   `https://native.hotwired.dev/ios/getting-started`
2. Hotwire Native Android getting started  
   `https://native.hotwired.dev/android/getting-started`
3. Hotwire Native path configuration overview/reference  
   `https://native.hotwired.dev/overview/path-configuration`  
   `https://native.hotwired.dev/reference/path-configuration`
4. Turbo-Rails server-driven native navigation  
   `https://native.hotwired.dev/reference/navigation`
5. Bridge installation (web app side)  
   `https://native.hotwired.dev/reference/bridge-installation`
6. OAuth for native app security guidance  
   `https://www.rfc-editor.org/rfc/rfc8252`

---

## 15. Handoff Notes for the Executing Agent

1. Start with WS1 before mobile shell work so backend behavior is stable.
2. Keep changes behind small commits and run tests after each workstream.
3. If Google OAuth native behavior is unclear, pause and force a product decision (Option A vs B); do not ship ambiguous behavior.
4. Do not scope-creep into API rewrite or Flutter migration during this implementation.

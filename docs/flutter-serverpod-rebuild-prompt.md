# Baehub Rebuild Prompt (Flutter + Serverpod)

Use the following prompt with your coding agent:

---

You are a senior Flutter + Serverpod engineer. Rebuild the existing **Baehub** Rails app as a production-ready Flutter app with a Serverpod backend, preserving behavior and business rules.

## Mission
- Build a clean, maintainable Flutter + Serverpod monorepo.
- Match existing product behavior and domain rules.
- Deliver in small, verifiable milestones with tests and runnable code at every step.
- Prefer clear architecture over shortcuts.

## Existing Product Summary (Source of Truth)
- App name: `Baehub`
- Current app type: Rails web app (with Hotwire native wrappers).
- Audience: Couples sharing tasks, events, and finances.
- Core areas:
1. Auth + user profile
2. Couple pairing + invitation codes
3. Tasks
4. Events + RSVP + recurrence
5. Expenses + split strategies + settlements
6. Dashboard + activity timeline
7. Settings + Google Calendar sync

## Tech Targets
- Frontend: Flutter (mobile-first, but keep layout responsive enough for tablet/web if enabled), with `flutter_hooks`, `hooks_riverpod`, `riverpod_annotation` + `riverpod_generator` (code gen), `go_router`, and `injector`.
- Backend: Serverpod (Postgres, typed endpoints, sessions/auth, background jobs/schedules) using `serverpod_auth_server` as the default auth system.
- DB: PostgreSQL
- Realtime: Stream/refresh where helpful (tasks/events feed updates can be pull-first, then websocket enhancement).
- CI: lint, format, tests.

## Required Architecture

### Backend (Serverpod)
- Organize by modules:
1. `auth`
2. `couples`
3. `invitations`
4. `tasks`
5. `events`
6. `event_responses`
7. `expenses`
8. `settlements`
9. `settings`
10. `activity`
11. `google_calendar_sync`
- Use Serverpod default auth (`serverpod_auth_server`) instead of rolling custom auth flows.
- Use explicit DTOs/models and avoid leaking internal DB objects directly.
- Add service layer for business logic (not in endpoints).
- Add policy/authorization checks per endpoint (user must belong to same couple for coupled resources).
- Add idempotency where relevant for webhook/event sync handling.

### Frontend (Flutter)
- Use feature-first folder structure.
- State management is required to use `hooks_riverpod` + `flutter_hooks`.
- Provider definitions must use Riverpod code generation (`riverpod_annotation`, `riverpod_generator`, `build_runner`) rather than manual providers where possible.
- Use `Injector` as the DI container for services/repositories/clients.
- Use `go_router` for all app navigation and route guards.
- Add typed API clients for Serverpod endpoints.
- Use Serverpod auth client packages for sign-in/session handling (`serverpod_auth_client`, `serverpod_auth_email_flutter`) and keep auth UX aligned with default Serverpod auth flows.
- Include form validation at UI + backend levels.
- Build screens:
1. Landing / auth entry
2. Sign up / sign in / account
3. Pairing screen (create couple, join by invite code)
4. Dashboard
5. Tasks list/detail/editor + filters
6. Events list + calendar views + detail/editor + filters
7. Expenses list/detail/editor + filters
8. Settlement create/edit
9. Settings (financial + appearance toggle + Google calendar connect/select/disconnect)
- Use clear loading/error/empty states.

## Domain Model to Implement

Implement the following entities and constraints:

1. `User`
- Fields: `authUserId` (link to Serverpod auth user), name, email, avatarUrl, preferredColor, timezone, role (`partner|solo`), soloMode, prefersDarkMode, coupleId nullable.
- Rules:
1. `name` required, 2..50 chars
2. `preferredColor` hex format when present
3. `paired` means `coupleId != null && soloMode == false`

2. `Couple`
- Fields: name, slug (unique), anniversaryOn, story, timezone (default UTC), defaultCurrency (default USD).
- Rules:
1. `defaultCurrency` in `[USD, EUR, GBP, JPY, CAD, AUD, PHP]`
2. slug auto-generated, unique
- Relationship: has users, invitations, tasks, events, expenses, settlements, reminders, activity logs, one google calendar connection.

3. `Invitation`
- Fields: code (8 chars, unique), senderId, coupleId, recipientEmail optional, message optional, status (`pending|redeemed|revoked|expired`), expiresAt, redeemedAt, revokedAt.
- Rules:
1. active = pending + not revoked + not expired
2. code uppercase alphanumeric

4. `Task`
- Fields: title, description, coupleId, creatorId, assigneeId nullable, status enum (`todo|in_progress|done|archived`), priority enum (`low|normal|high|urgent`), dueAt, completedAt.
- Rules:
1. title required max 120
2. description max 2000
3. assignee must belong to same couple
4. archived tasks cannot transition back to other statuses
5. completedAt auto-managed when status changes to/from done

5. `Event`
- Fields: title, description, coupleId, creatorId, startsAt, endsAt nullable, allDay bool, recurrenceRule nullable in format `frequency:interval:end_date`, syncToGoogle bool, sync metadata fields.
- Recurrence:
1. frequency in `daily|weekly|monthly|yearly`
2. interval positive int
3. end_date = `never` or valid date
- Rules:
1. title required max 140
2. description max 2000
3. startsAt required
4. endsAt >= startsAt when present
5. all-day normalization: start to day start, end to day end in couple timezone
6. if syncToGoogle true, selected Google calendar must exist

6. `EventResponse`
- Fields: eventId, userId, status (`pending|accepted|declined`), respondedAt.
- Rules:
1. unique(eventId, userId)
2. user cannot RSVP own event
3. user must belong to same couple
4. respondedAt set when status != pending, cleared when pending

7. `Expense`
- Fields: title, amountCents, incurredOn, notes, coupleId, spenderId, splitStrategy (`equal|percentage|custom_amounts`).
- Rules:
1. title required max 140
2. amountCents > 0
3. spender must belong to same couple

8. `ExpenseShare`
- Fields: expenseId, userId nullable, amountCents nullable, percentage nullable.
- Rules:
1. unique(expenseId, userId) when user present
2. either amountCents or percentage required
3. percentage 0..100 when present
4. amountCents >= 0 when present
5. user must belong to expense couple

9. `Settlement`
- Fields: coupleId, payerId, payeeId, amountCents, settledOn, notes.
- Rules:
1. amountCents > 0 and <= 10,000,000
2. payer != payee
3. payer/payee must belong to same couple
4. helper conversion for decimal currency input to cents with proper rounding

10. `ActivityLog`
- Fields: coupleId, userId nullable, action, subjectType nullable, subjectId nullable, metadata json, createdAt.
- Rules:
1. action required max 120
2. metadata required
3. recent feed limit ~20

11. `GoogleCalendarConnection`
- Fields: coupleId(unique), userId, accessToken, refreshToken, expiresAt, calendarId, calendarSummary, syncToken, lastSyncedAt, webhook channel fields (`channelId`, `channelToken`, `channelResourceId`, `channelExpiresAt`).

## Critical Business Logic

### Pairing
- User can create couple if not already coupled.
- User can join with active invite code.
- Invite code redemption links user to couple and marks invite redeemed.
- Enforce practical couple size guard like current app (don’t allow overfilling).

### Task filtering/sorting
- Filter by status, assignee, due date.
- Sort options:
1. status asc
2. due asc
3. due desc
4. priority desc
5. default status + due ordering with null due dates last

### Event filtering/sorting/views
- Filters: upcoming, past, current_week, future + date range filter.
- Views:
1. list
2. month calendar
3. week calendar
4. day calendar
- Expand recurring events into occurrences for display windows.

### RSVP
- Non-creator partner can create/update RSVP.
- Invalid status rejected.
- Log RSVP activity.

### Expenses + splits
- Equal split: divide cents equally, distribute remainder deterministically.
- Percentage split: percentages must total 100 (allow tiny tolerance).
- Custom amounts: amounts must total exact expense cents.

### Balance calculation
- For each user:
1. paid from expenses as spender
2. owes from shares
3. settlements made
4. settlements received
- Net = (paid - owes) + settlements_made - settlements_received.
- Summary output should identify debtor/creditor and amount owed.

### Settlements
- Record payment between partners, affects balances.
- CRUD with validation and activity logs.

### Settings
- Couple financial preference: default currency.
- User preference: dark mode boolean (store now even if theme rollout is partial).
- Google calendar connection management in settings flow.

## Google Calendar Sync (Bidirectional)

Implement parity-level behavior:
- OAuth connect (state validation).
- Select calendar from writable/owned calendars.
- Initial sync job after calendar selection.
- Pull changes using sync token; fallback to full sync on token invalidation.
- Upsert local events to Google when `syncToGoogle=true`.
- Delete remote event when local synced event deleted or sync disabled.
- Webhook endpoint validates channel token and enqueues pull job.
- Renew webhook watch on schedule (daily check/refresh).
- Prevent sync loops via `skipGoogleSync` style internal flags and timestamp comparisons.

## API Surface (Implement)

Define endpoints for:
1. Use Serverpod default auth endpoints/session flow (no custom login/signup endpoints unless strictly needed for app-specific profile completion)
2. Couple create/get/update
3. Invitation create/revoke/list active
4. Join by invite code
5. Tasks CRUD + toggle completion + filtered query
6. Events CRUD + filtered query + calendar window query
7. Event responses create/update
8. Expenses CRUD + split payload handling
9. Settlements CRUD/list
10. Dashboard aggregate endpoint
11. Activity feed endpoint
12. Settings get/update
13. Google connect callback handling + select calendar + disconnect + webhook receive

Use pagination for list endpoints where needed.

## UX Expectations
- Preserve major UX intent:
1. Dashboard quick actions (new task/event/expense)
2. Invite banner when partner missing
3. Activity timeline
4. Filters as dedicated sheets/dialogs
5. Clear card-based sections for Tasks, Events, Finances
- Keep forms practical and fast for mobile.
- Keep date/time timezone-aware using couple timezone where business logic needs it.

## Migration & Delivery Plan

Execute in phases with a commit per phase:

1. Foundation
- Setup Serverpod + Flutter app, env config, CI checks.
- Configure Flutter architecture baseline with `hooks_riverpod` + codegen, `Injector`, and `go_router`.
- Configure Serverpod default auth module (`serverpod_auth_server`) and Flutter auth client wiring.

2. Auth + Pairing
- Serverpod default auth integration, then couple create/join and invitation lifecycle.

3. Tasks
- Full CRUD + filters + activity logging.

4. Events + Recurrence + RSVP
- Event CRUD, recurrence parsing/expansion, calendar/list views, responses.

5. Expenses + Settlements + Balances
- Split strategies, shares, balance calculation, settlement flows.

6. Dashboard + Settings
- Aggregates, preferences, polished UX states.

7. Google Calendar Sync
- OAuth, calendar selection, jobs, webhook, conflict handling.

8. Hardening
- Integration tests, edge cases, observability, seed data, docs.

After each phase provide:
1. What was built
2. What remains
3. Commands to run
4. Screens/endpoints validated

## Testing Requirements

Write tests for:
1. Model validations and transitions (task archived rule, event recurrence parsing, settlement conversions)
2. Authorization (cross-couple access denied)
3. Expense split calculations (equal with remainders, percentage totals, custom amount totals)
4. Balance computation scenarios (including settlements and overpayment)
5. Recurring event occurrence expansion
6. RSVP restrictions
7. Google sync services (unit tests with mocked HTTP)
8. Endpoint tests for key flows

Add seed data for realistic manual QA:
- one couple with two users
- sample tasks/events (including recurring/all-day)
- expenses with all split strategies
- settlements
- activity logs

## Non-Functional Requirements
- Strong typing end-to-end.
- Structured logging and error handling.
- Do not store money as floating point; use integer cents.
- Keep timezone handling explicit and consistent.
- Keep secrets in env/config, never hardcoded.

## Output Format
- Start by generating:
1. high-level architecture diagram (text/markdown)
2. file/folder structure
3. DB schema
4. endpoint contract table
5. phased implementation checklist
- Then implement phase by phase.
- Do not skip tests.
- When uncertain, choose behavior matching the constraints in this prompt.

---

If any requirement conflicts during implementation, preserve domain correctness and data integrity first, then UI parity.

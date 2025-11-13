# Joint Account Borrowing Feature Plan

## Objectives
- Enable partners to register a shared joint account that can track bilateral borrowing with individual partners.
- Allow partners to initiate borrow transactions either from the joint account or lend to it, with precise repayment tracking.
- Provide settlement workflows that clearly close out outstanding balances and produce an auditable trail.
- Maintain full visibility for all joint account members through dashboards, notifications, and history views.

## Scope
- Rails backend changes: models, migrations, controllers/services, background jobs, validations, auditing, and notifications.
- Frontend updates in views and Stimulus controllers to manage joint account setup, borrowing, and settlements.
- Analytics, audit logging, and automated tests covering the new functionality.

## Assumptions
- Partners already exist in the system and have authenticated access.
- Monetary amounts are tracked in the same currency system used by the rest of the app.
- Joint accounts are only shared between partners already linked in the application.
- Existing authorization framework can be extended for joint account permissions.

## Core Concepts
- **Joint Account**: Entity representing the shared account with metadata such as name, currency, status, and defaults.
- **Membership**: Relationship rows connecting partners to joint accounts, storing roles and join dates.
- **Borrow Transaction**: Immutable ledger entry capturing direction (partner to joint account, or joint account to partner), amount, rationale, timestamps, and settlement status.
- **Balance Snapshot**: Derived view showing net owed amounts per partner and for the joint account overall.
- **Settlement**: Operation that marks a set of borrow transactions as resolved, optionally with supporting payment evidence.

## Domain Model and Data Design
- Create `JointAccount` model with attributes: `name`, `currency`, `created_by_partner_id`, `status`, `settings_jsonb`, `created_at`, `updated_at`.
- Create `JointAccountMembership` model with attributes: `joint_account_id`, `partner_id`, `role` (enum), `joined_at`, `left_at`, boolean `active`.
- Create `JointAccountLedgerEntry` model to store each borrowing event with attributes: `joint_account_id`, `initiator_partner_id`, `counterparty_partner_id` (nullable when the joint account borrows), `direction` (enum with values `partner_owes_joint_account`, `joint_account_owes_partner`), `amount_cents`, `currency`, `description`, `metadata_jsonb`, `settled_at`, `settlement_reference`, `created_at`, `updated_at`.
- Introduce `JointAccountBalance` materialized view or cached aggregate table to accelerate balance queries per partner and per joint account; refresh after every transaction or on schedule.
- Add ActiveRecord enums for `status`, `role`, and `direction` with symbol-based mappings.
- Enforce database constraints for foreign keys, non-null critical attributes, and check constraints on positive amounts.
- Ensure soft-deletion strategy (if used elsewhere) is honored; otherwise record archival data with boolean flags.

## Business Rules
- Only active members can initiate borrow or settlement actions.
- Amounts must be positive integers in cents; validation rejects zero or negative values.
- `JointAccountLedgerEntry` rows are immutable once created; settlement adds timestamps and references without altering amount or direction.
- A settlement can close multiple ledger entries; store settlement grouping in a join table if bulk settlement is required (`JointAccountSettlement` with `JointAccountSettlementEntry`).
- Prevent borrow actions if the joint account is inactive or the partner membership is inactive.
- Enforce configurable caps per transaction and per partner (store thresholds in `settings_jsonb`).
- Record metadata for repayment channels (e.g., bank transfer, cash) and optionally attachments for proof using ActiveStorage.

## API and Service Layer
- Service objects:
  - `JointAccounts::Creator` to handle creation and membership invitations.
  - `JointAccounts::BorrowProcessor` to validate and persist ledger entries for both directions.
  - `JointAccounts::SettlementProcessor` to close outstanding entries and update snapshots.
  - `JointAccounts::BalanceRefresher` to maintain cached balances.
- Controller endpoints or actions:
  - `POST /joint_accounts` for creation.
  - `POST /joint_accounts/:id/borrow` handling partner initiated borrow against the joint account.
  - `POST /joint_accounts/:id/lend` when the joint account borrows from a partner.
  - `POST /joint_accounts/:id/settlements` to settle outstanding entries.
  - `GET /joint_accounts/:id/ledger` and `GET /joint_accounts/:id/balances` for history and balance views.
- Authorization integration using existing policy framework to ensure only members can access and modify joint account data.

## User Experience and Interface
- Settings view enhancements to let partners create and configure joint accounts, select members, and define borrowing rules.
- Joint account dashboard showing:
  - Current net balances per member.
  - Recent transactions with filters.
  - Call-to-action buttons for borrowing and settlements.
- Borrow flow modal or page:
  - Direction selector (partner borrowing vs joint account borrowing).
  - Amount input with validation and currency display.
  - Description and optional attachment uploader.
  - Confirmation step summarizing the ledger entry.
- Settlement flow:
  - Select outstanding entries to settle.
  - Input settlement details (date, amount, reference, attachment).
  - Post-confirmation success view with updated balances.
- Accessibility and responsive layout updates where necessary.

## Notifications and Communications
- Email and in-app notifications triggered when:
  - New joint account is created and user is added as member.
  - Borrow transaction is recorded affecting a partner.
  - Settlement is completed involving a partner.
- Optional digest summarizing weekly joint account activity.
- Respect user notification preferences already stored in the system.

## Background Jobs and Scheduling
- Job to refresh balance snapshots after each transaction or on schedule when batch settlement occurs.
- Reminder job to notify partners about outstanding balances approaching due dates.
- Optional daily reconciliation job that validates ledger integrity and flags inconsistencies.

## Security and Compliance
- Reuse existing authentication and add policy checks for every joint account action.
- Ensure only joint account members can view ledger entries and balances.
- Log critical actions with partner id, joint account id, and request metadata.
- Validate attachment uploads against size and type restrictions.
- Consider rate limiting for borrow actions to mitigate abuse.

## Analytics and Reporting
- Track metrics: number of joint accounts, total borrowed amounts, average settlement duration, outstanding balance per partner.
- Emit analytics events from service layer for borrow and settlement actions.
- Provide export functionality (CSV) for joint account ledger within permitted limits.

## Testing Strategy
- Unit tests for new models, validations, and service objects.
- Request or controller tests covering success and failure scenarios for each new endpoint.
- Feature tests simulating end-to-end flows: create joint account, borrow, settle, notification delivery.
- Background job tests ensuring balance refreshes and reminders trigger correctly.
- Data integrity tests verifying snapshot accuracy and settlement grouping.

## Deployment and Migration Plan
- Create migrations for new tables and indexes; backfill data only after migrations run.
- Deploy feature behind a feature flag scoped per partner or per joint account.
- Run migrations in standard deployment pipeline; verify with staging data.
- Post-deploy smoke tests on staging: create joint account, execute borrow, verify balances, settle.
- Monitor background job queues and error trackers after release.

## Documentation and Training
- Update user-facing documentation with steps to create joint accounts, borrow, and settle.
- Provide internal runbooks for customer support with common troubleshooting scenarios.
- Include developer notes on service usage, ledger invariants, and feature flag operations.

## Implementation Guidelines
- Favor immutable data structures and typed variables in Ruby and JavaScript layers; declare `const` where appropriate in frontend code.
- Use existing money handling utilities to avoid floating point calculations.
- Ensure migrations are reversible and follow zero-downtime practices.

## Open Questions
- Should joint accounts support more than two partners by default?
- Do we need approval workflow before a borrow entry becomes active?
- What reporting access do administrators require for auditing?
- How should currency conversion be handled if partners operate in multiple currencies?

## Next Steps
- Validate assumptions with stakeholders and resolve open questions.
- Create detailed tickets for backend, frontend, QA, and documentation tasks based on this plan.
- Prioritize minimal viable scope for initial release and sequence follow-up enhancements.

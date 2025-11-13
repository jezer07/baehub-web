# Joint Account Borrowing Implementation Plan

## Overview
- Deliver the joint account borrowing feature in iterative milestones, ensuring data integrity, auditability, and intuitive UX.
- Align backend, frontend, notifications, analytics, and operational readiness across teams.
- Maintain feature flag control for staged rollout and facilitate quick rollback if needed.

## Milestones
- **Milestone 0 – Discovery (Week 0)**
  - Confirm requirements, resolve open questions, and finalize acceptance criteria.
  - Produce wireframes for joint account dashboard, borrow flow, and settlement flow.
  - Identify dependencies on external services, money handling utilities, and notification channels.
- **Milestone 1 – Data Foundations (Weeks 1-2)**
  - Ship migrations for joint account, membership, ledger, settlement, and balance snapshot tables.
  - Implement ActiveRecord models, enums, validations, and associations.
  - Introduce service scaffolding with contract tests for creation, borrow processing, settlements, and balance refresh.
- **Milestone 2 – Backend Services & APIs (Weeks 2-4)**
  - Build service objects with business logic, invariants, and transaction handling.
  - Expose REST endpoints or controller actions for create, borrow, lend, settle, ledger query, and balance query.
  - Integrate policy checks and background jobs for balance refresh and reminders.
- **Milestone 3 – Frontend Experience (Weeks 3-5)**
  - Implement settings UI for joint account management and membership configuration.
  - Build dashboard view, borrow modal, and settlement flow with Stimulus controllers.
  - Connect frontend to APIs, handle form validations, show real-time balance updates.
- **Milestone 4 – Notifications & Analytics (Week 5)**
  - Configure mailers and in-app notifications for key events.
  - Emit analytics events and set up dashboards for monitoring adoption and usage.
- **Milestone 5 – Quality Assurance & Hardening (Weeks 5-6)**
  - Complete automated testing, manual QA scripts, and regression passes.
  - Finalize documentation, support runbooks, and training assets.
- **Milestone 6 – Launch & Post-Launch (Week 7)**
  - Enable feature flag for pilot partners, monitor metrics, and gather feedback.
  - Iterate on issues, expand rollout, and archive lessons learned.

## Workstreams
- **Backend**
  - Define database schema, indexes, constraints, and migration sequencing.
  - Implement service objects with immutable inputs and outputs.
  - Add balance snapshot refresh logic (materialized view or cached aggregate).
  - Integrate with auditing and logging utilities.
- **Frontend**
  - Extend Stimulus controllers with const bindings and typed targets where applicable.
  - Build modular components for dashboard cards, transaction lists, and forms.
  - Handle error states, loading indicators, and optimistic UI updates.
- **Notifications**
  - Configure notifier classes for email, push, and in-app channels.
  - Respect user notification preferences and rate limits.
  - Add background jobs for scheduled reminders and weekly digests.
- **Analytics**
  - Track creation, borrow, settlement, and reminder events.
  - Provide analytics dashboards for product and support teams.
- **QA & Testing**
  - Expand unit, request, and feature specs covering positive and negative paths.
  - Add background job and policy tests to ensure access control correctness.
  - Prepare manual QA scripts and smoke tests for staging verification.
- **Operational Readiness**
  - Update runbooks, alerting rules, and on-call procedures.
  - Ensure feature flag configuration and monitoring hooks are ready pre-launch.

## Detailed Task Breakdown
- **Data Layer**
  - Author migrations with reversible operations and safe deployment patterns.
  - Implement models: `JointAccount`, `JointAccountMembership`, `JointAccountLedgerEntry`, `JointAccountSettlement`, `JointAccountSettlementEntry`, `JointAccountBalance`.
  - Add model-level validations, scopes, and callbacks (if required) while preserving immutability of ledger records.
  - Write database-level constraints and indexes for performance and integrity.
- **Business Logic**
  - Implement creators and processors using service objects with explicit contracts.
  - Enforce business rules: membership checks, amount validation, status checks, settlement grouping.
  - Add money utilities to handle currency formatting and conversions if needed.
- **API Layer**
  - Extend routes for joint account operations.
  - Implement controller actions delegating to services, handling errors, and rendering structured JSON or HTML responses.
  - Apply policy checks with existing authorization framework.
- **Background Jobs**
  - Create jobs for balance refresh, reminder notifications, and reconciliation audits.
  - Ensure idempotency and retry policies are defined.
- **Frontend Implementations**
  - Update settings pages for joint account creation with member selection.
  - Build dashboard view showing balances, transactions, and actions.
  - Implement borrow and settlement forms with validation, confirmation step, and success feedback.
  - Connect to backend endpoints via fetch or Rails UJS, handling CSRF tokens and error states.
- **Notifications & Communications**
  - Add mailer templates for new account, borrow event, settlement confirmation, and reminders.
  - Configure in-app notification components and badge updates.
  - Document notification triggers and content for support reference.
- **Analytics & Reporting**
  - Instrument events in service layer and frontend.
  - Provide CSV export endpoint or background job for ledger history.
  - Coordinate with analytics team to surface dashboards and alerts.
- **Testing & QA**
  - Write unit tests for models, services, policies, background jobs.
  - Add request specs covering success, failure, and authorization scenarios.
  - Create feature specs for end-to-end flows (create joint account, borrow, settle).
  - Draft manual QA checklist including accessibility and responsive checks.
- **Documentation**
  - Update README or feature docs with setup instructions.
  - Produce internal knowledge base articles and customer-facing guides.
  - Record architectural decisions (ADR) for ledger immutability and balance snapshots.

## Timeline & Dependencies
- Total estimated duration: seven weeks with overlapping workstreams.
- Critical dependencies:
  - Availability of design assets for frontend milestones.
  - Confirmation of notification templates and copy.
  - Infrastructure support for new background jobs and feature flagging.
- Risk mitigations:
  - Use feature flags to isolate release.
  - Maintain seed data and staging scenarios for rapid QA.
  - Schedule weekly cross-functional syncs to surface blockers early.

## Acceptance Criteria Summary
- Joint account creation, borrowing, lending, and settlement flows function end-to-end for active members.
- Ledger entries are immutable, auditable, and reflected in balance snapshots.
- UI surfaces current balances, transaction history, and settlement status clearly.
- Notifications and analytics capture key events without duplication.
- Automated test coverage meets agreed thresholds; manual QA sign-off complete.
- Runbooks, documentation, and support materials updated prior to launch.

## Launch Checklist
- Verify migrations applied successfully in staging and production.
- Confirm feature flag defaults to off and scoped to pilot users at launch.
- Execute smoke tests: create account, borrow, settle, verify notifications.
- Monitor logs, metrics, and job queues immediately after rollout.
- Gather partner feedback and plan follow-up iterations.

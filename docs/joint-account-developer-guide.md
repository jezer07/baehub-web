# Joint Account Feature - Developer Guide

## Quick Start

### Creating a Joint Account
```ruby
result = JointAccounts::Creator.new(
  couple: current_couple,
  creator_user: current_user,
  params: {
    name: "Vacation Fund",
    currency: "USD",
    member_ids: [user1.id, user2.id]
  }
).call

if result[:success]
  joint_account = result[:joint_account]
else
  errors = result[:errors]
end
```

### Recording a Borrow Transaction
```ruby
result = JointAccounts::BorrowProcessor.new(
  joint_account: joint_account,
  initiator_user: current_user,
  params: {
    direction: "partner_owes_joint_account",
    amount_cents: 50000,
    currency: "USD",
    description: "Borrowed for vacation"
  }
).call
```

### Processing a Settlement
```ruby
result = JointAccounts::SettlementProcessor.new(
  joint_account: joint_account,
  settled_by_user: current_user,
  params: {
    ledger_entry_ids: [1, 2, 3],
    total_amount_cents: 150000,
    currency: "USD",
    settlement_date: Date.current,
    notes: "Paid back via bank transfer",
    payment_method: "bank_transfer"
  }
).call
```

### Refreshing Balances
```ruby
result = JointAccounts::BalanceRefresher.new(
  joint_account: joint_account,
  user: user
).call

result = JointAccounts::BalanceRefresher.new(
  joint_account: joint_account
).call
```

## Service Object Pattern

All services follow the same pattern:

### Input
- Constructor takes required objects and params hash
- Validates inputs before processing

### Output
- Returns hash with `:success` boolean
- On success: includes created/updated record
- On failure: includes `:errors` array

### Example
```ruby
result = ServiceClass.new(required_args, params: {}).call

if result[:success]
  record = result[:record_name]
else
  errors = result[:errors]
end
```

## Model Relationships

### JointAccount
```ruby
joint_account.couple
joint_account.created_by
joint_account.users
joint_account.active_members
joint_account.joint_account_ledger_entries
joint_account.joint_account_balances
```

### User
```ruby
user.joint_accounts
user.created_joint_accounts
user.joint_account_memberships
user.joint_account_ledger_entries_initiated
user.joint_account_balances
```

## Querying

### Find Active Accounts
```ruby
JointAccount.active_accounts
```

### Find Unsettled Transactions
```ruby
joint_account.joint_account_ledger_entries.unsettled
```

### Find Outstanding Balances
```ruby
joint_account.joint_account_balances.where.not(balance_cents: 0)
```

### Filter by Direction
```ruby
JointAccountLedgerEntry.by_direction(:partner_owes_joint_account)
```

## Background Jobs

### Refresh Balance
```ruby
JointAccounts::BalanceRefreshJob.perform_later(joint_account.id)
JointAccounts::BalanceRefreshJob.perform_later(joint_account.id, user.id)
```

### Send Reminders
```ruby
JointAccounts::ReminderJob.perform_later
```

### Run Reconciliation
```ruby
JointAccounts::ReconciliationJob.perform_later
```

## Email Notifications

Emails are automatically sent via service objects:

- Account creation → Added members receive welcome email
- Borrow transaction → All members (except initiator) notified
- Settlement → All members (except settler) notified

Manual email sending:
```ruby
JointAccountMailer.outstanding_balance_reminder(balance).deliver_later
```

## Testing

### Model Tests
```ruby
test "should validate amount" do
  entry = joint_account_ledger_entries(:one)
  entry.amount_cents = 0
  assert_not entry.valid?
end
```

### Service Tests
```ruby
test "should create joint account" do
  result = JointAccounts::Creator.new(
    couple: @couple,
    creator_user: @user,
    params: { name: "Test" }
  ).call
  
  assert result[:success]
end
```

### Controller Tests
```ruby
test "should create joint account" do
  assert_difference("JointAccount.count") do
    post joint_accounts_path, params: {
      joint_account: { name: "Test", currency: "USD" }
    }
  end
end
```

## Common Patterns

### Check Membership
```ruby
if joint_account.member?(user)
end
```

### Get User Balance
```ruby
balance_cents = joint_account.outstanding_balance_for(user)
```

### Get Total Outstanding
```ruby
total = joint_account.total_outstanding_balance
```

### Check Settlement Status
```ruby
if ledger_entry.settled?
end
```

## Currency Handling

All amounts stored in cents:
```ruby
dollars = 50.00
cents = (dollars * 100).round

amount_cents = 5000
dollars = amount_cents / 100.0
formatted = sprintf('%.2f', dollars)
```

Currency symbols via catalog:
```ruby
symbol = CurrencyCatalog.symbol_for("USD")
```

## Enums

### JointAccount Status
- `active`: Can perform transactions
- `inactive`: Temporarily disabled
- `archived`: Soft-deleted

### Membership Role
- `admin`: Full control
- `member`: Standard access

### Ledger Direction
- `partner_owes_joint_account`: Partner borrowed from account
- `joint_account_owes_partner`: Account borrowed from partner

## Error Handling

Services validate and return errors:
```ruby
result = service.call

unless result[:success]
  flash[:alert] = result[:errors].join(", ")
  redirect_back fallback_location: root_path
end
```

## Authorization Checks

Controllers enforce:
- User must be signed in
- User must have a couple
- User must be member of joint account

Service objects validate:
- Joint account must be active
- User must be active member
- Amounts must be positive
- Ledger entries must be unsettled for settlement

## Performance Considerations

### Indexes Used
- Foreign keys indexed
- Status fields indexed
- Date fields indexed
- Composite indexes on common queries

### N+1 Query Prevention
```ruby
joint_accounts.includes(:joint_account_memberships, :created_by)
ledger_entries.includes(:initiator, :counterparty)
balances.includes(:user)
```

### Balance Caching
Balances are cached in separate table and refreshed after transactions.

## Debugging

### Check Balance Integrity
```ruby
JointAccounts::ReconciliationJob.perform_now
```

### Manually Refresh Balance
```ruby
balance = joint_account.joint_account_balances.find_by(user: user)
balance.refresh!
```

### View Ledger Entries for Balance
```ruby
joint_account.joint_account_ledger_entries
  .unsettled
  .where("initiator_id = ? OR counterparty_id = ?", user.id, user.id)
```

## Configuration

### Settings JSONB
Joint accounts have flexible settings:
```ruby
joint_account.settings = {
  max_transaction_cents: 100000,
  require_approval: false,
  notification_preferences: {}
}
```

### Metadata JSONB
Ledger entries and settlements support metadata:
```ruby
ledger_entry.metadata = {
  category: "vacation",
  notes: "Flight tickets",
  attachments: []
}
```

## Common Gotchas

1. **Amount Conversion**: Always convert dollars to cents in controller
2. **Immutability**: Ledger entries cannot be updated, only settled
3. **Currency Matching**: Ensure currency matches when settling
4. **Member Validation**: User must be couple member before adding to account
5. **Deletion**: Cannot delete accounts with unsettled transactions

## Support

For questions or issues, refer to:
- Implementation Plan: `docs/joint-account-borrowing-plan.md`
- Implementation Details: `docs/joint-account-borrowing-implementation.md`
- Summary: `docs/joint-account-borrowing-implementation-summary.md`


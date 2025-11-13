# Joint Account Feature - SQLite Compatibility Notes

## Database Differences

The joint account feature was originally designed for PostgreSQL but has been adapted for SQLite compatibility.

## Changes Made for SQLite

### 1. JSON Storage
**PostgreSQL**: `jsonb` column type  
**SQLite**: `text` column type with Rails serialization

Files affected:
- `settings` in JointAccount
- `metadata` in JointAccountLedgerEntry  
- `metadata` in JointAccountSettlement

### 2. Model Serialization
Added to models:
```ruby
serialize :settings, coder: JSON
serialize :metadata, coder: JSON
```

This automatically converts:
- Hash → JSON string (when saving)
- JSON string → Hash (when loading)

### 3. Indexes
**PostgreSQL**: GIN indexes for JSONB columns  
**SQLite**: Removed (not supported)

Removed indexes:
- `joint_accounts.settings`
- `joint_account_ledger_entries.metadata`
- `joint_account_settlements.metadata`

## Usage

The API remains identical regardless of database:

```ruby
joint_account.settings = { max_transaction_cents: 100000 }
joint_account.save!

joint_account.settings[:max_transaction_cents]
```

Rails handles the serialization automatically.

## Default Values

Migrations set default as JSON string:
```ruby
t.text :settings, null: false, default: "{}"
```

Models ensure hash initialization:
```ruby
def ensure_settings
  self.settings ||= {}
end
```

## Performance Considerations

### PostgreSQL Advantages
- Native JSON operators and functions
- GIN indexing for fast JSON queries
- Better performance for complex JSON queries

### SQLite Considerations
- JSON stored as text
- Full column scans for JSON searches
- Sufficient for small-to-medium datasets

## Migration Path

If migrating to PostgreSQL later:

1. Change column types:
```ruby
change_column :joint_accounts, :settings, :jsonb, using: 'settings::jsonb'
change_column :joint_account_ledger_entries, :metadata, :jsonb, using: 'metadata::jsonb'
change_column :joint_account_settlements, :metadata, :jsonb, using: 'metadata::jsonb'
```

2. Add GIN indexes:
```ruby
add_index :joint_accounts, :settings, using: :gin
add_index :joint_account_ledger_entries, :metadata, using: :gin
add_index :joint_account_settlements, :metadata, using: :gin
```

3. Remove serialization from models:
```ruby
serialize :settings, coder: JSON
serialize :metadata, coder: JSON
```

No other code changes needed!

## Testing

All tests work identically with both databases. The serialization is transparent to the application layer.


# Upgrade Guide: v2.5.x → v2.6.0

## Overview

v2.6.0 adds instance-level subscription support ([#202](https://github.com/simukappu/activity_notification/issues/202)). This requires a database migration for existing installations.

**You must run the migration before deploying the updated gem.** The gem will raise errors if the new columns are missing.

## Step 1: Update the gem

```ruby
# Gemfile
gem 'activity_notification', '~> 2.6.0'
```

```console
$ bundle update activity_notification
```

## Step 2: Run the migration

### ActiveRecord

Generate and run the migration:

```console
$ bin/rails generate activity_notification:add_notifiable_to_subscriptions
$ bin/rails db:migrate
```

This will:
- Add `notifiable_type` (string, nullable) and `notifiable_id` (integer, nullable) columns to the `subscriptions` table
- Remove the old unique index on `[:target_type, :target_id, :key]`
- Add a new unique index on `[:target_type, :target_id, :key, :notifiable_type, :notifiable_id]` with prefix lengths for MySQL compatibility

### Mongoid

No migration is needed. Mongoid is schemaless and the new fields will be added automatically. However, if you have custom indexes on the subscriptions collection, you may want to update them:

```console
$ bin/rails db:mongoid:create_indexes
```

### Dynamoid

No migration is needed. The new `notifiable_key` field will be added automatically to new records.

## Step 3: Verify

After migrating, verify that existing subscriptions still work:

```ruby
# Existing key-level subscriptions should still work
user.subscribes_to_notification?('comment.default')  # => true/false as before
```

## What changed

### Subscription queries

Key-level subscription lookups now explicitly filter by `notifiable_type IS NULL`. This ensures that instance-level subscriptions (where `notifiable_type` is set) are not confused with key-level subscriptions.

Before:
```ruby
subscriptions.where(key: key).first
```

After:
```ruby
subscriptions.where(key: key, notifiable_type: nil).first
```

For existing databases where all subscriptions have `NULL` notifiable fields, the results are identical.

### Method signature changes

The following methods have new optional keyword arguments. Existing calls without these arguments are fully compatible:

- `find_subscription(key, notifiable: nil)` — pass `notifiable:` to look up instance-level subscriptions
- `find_or_create_subscription(key, subscription_params)` — pass `notifiable:` in `subscription_params` to create instance-level subscriptions
- `subscribes_to_notification?(key, subscribe_as_default, notifiable: nil)` — pass `notifiable:` to check instance-level subscriptions

### Uniqueness constraint

The subscription uniqueness constraint now includes `notifiable_type` and `notifiable_id`. This allows a target to have:
- One key-level subscription per key (where notifiable is NULL)
- One instance-level subscription per key per notifiable instance

## Using instance-level subscriptions

```ruby
# Subscribe a user to notifications from a specific post
user.create_subscription(
  key: 'comment.default',
  notifiable_type: 'Post',
  notifiable_id: post.id
)

# Check if user subscribes to notifications from this specific post
user.subscribes_to_notification?('comment.default', notifiable: post)

# Find an instance-level subscription
user.find_subscription('comment.default', notifiable: post)

# When notify is called, targets from instance-level subscriptions
# are automatically merged with notification_targets
Notification.notify(:users, comment)
```

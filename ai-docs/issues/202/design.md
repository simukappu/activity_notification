# Issue #202: Instance-Level Subscriptions - Design

## Schema Changes

### Subscription Table

Add two nullable polymorphic columns to the `subscriptions` table:

```
notifiable_type  :string, index: true, null: true
notifiable_id    :bigint, index: true, null: true  (or :string for Mongoid/Dynamoid)
```

- `NULL` notifiable fields = key-level subscription (existing behavior)
- Non-NULL notifiable fields = instance-level subscription

### Unique Constraint

Replace the existing unique index:
```
# Before
add_index :subscriptions, [:target_type, :target_id, :key], unique: true

# After
add_index :subscriptions, [:target_type, :target_id, :key, :notifiable_type, :notifiable_id],
          unique: true, name: 'index_subscriptions_uniqueness'
```

This allows:
- One key-level subscription per (target, key) where notifiable is NULL
- One instance-level subscription per (target, key, notifiable) combination

**Note:** Most databases treat NULL as distinct in unique indexes, so `(user1, 'comment.default', NULL, NULL)` and `(user1, 'comment.default', 'Post', 1)` are considered different. For databases that don't, a partial/conditional index may be needed.

### Model Validations

Update uniqueness validation in all three ORM implementations:

```ruby
# ActiveRecord
validates :key, presence: true, uniqueness: { scope: [:target, :notifiable_type, :notifiable_id] }

# Mongoid
validates :key, presence: true, uniqueness: { scope: [:target_type, :target_id, :notifiable_type, :notifiable_id] }

# Dynamoid
validates :key, presence: true, uniqueness: { scope: :target_key }
# (Dynamoid uses composite keys, needs separate handling)
```

## Core Logic Changes

### 1. Subscription Model (All ORMs)

Add `belongs_to :notifiable` polymorphic association (optional):

```ruby
# ActiveRecord
belongs_to :notifiable, polymorphic: true, optional: true

# Mongoid
belongs_to_polymorphic_xdb_record :notifiable, optional: true

# Dynamoid
belongs_to_composite_xdb_record :notifiable, optional: true
```

Add scopes for filtering:

```ruby
scope :key_level_only,      -> { where(notifiable_type: nil) }
scope :instance_level_only, -> { where.not(notifiable_type: nil) }
scope :for_notifiable,      ->(notifiable) { where(notifiable_type: notifiable.class.name, notifiable_id: notifiable.id) }
```

### 2. Subscriber Concern (`models/concerns/subscriber.rb`)

Update `_subscribes_to_notification?` to only check key-level subscriptions:

```ruby
def _subscribes_to_notification?(key, subscribe_as_default = ...)
  evaluate_subscription(
    subscriptions.where(key: key, notifiable_type: nil).first,
    :subscribing?,
    subscribe_as_default
  )
end
```

Add new method for instance-level subscription check:

```ruby
def _subscribes_to_notification_for_instance?(key, notifiable, subscribe_as_default = ...)
  instance_sub = subscriptions.where(key: key, notifiable_type: notifiable.class.name, notifiable_id: notifiable.id).first
  instance_sub.present? && instance_sub.subscribing?
end
```

Update `find_subscription` to support optional notifiable:

```ruby
def find_subscription(key, notifiable: nil)
  if notifiable
    subscriptions.where(key: key, notifiable_type: notifiable.class.name, notifiable_id: notifiable.id).first
  else
    subscriptions.where(key: key, notifiable_type: nil).first
  end
end
```

### 3. Target Concern (`models/concerns/target.rb`)

Update `subscribes_to_notification?` to accept optional notifiable:

```ruby
def subscribes_to_notification?(key, subscribe_as_default = ..., notifiable: nil)
  return true unless subscription_allowed?(key)
  _subscribes_to_notification?(key, subscribe_as_default) ||
    (notifiable.present? && _subscribes_to_notification_for_instance?(key, notifiable, subscribe_as_default))
end
```

### 4. Notification API (`apis/notification_api.rb`)

#### `generate_notification` - Add instance-level check

```ruby
def generate_notification(target, notifiable, options = {})
  key = options[:key] || notifiable.default_notification_key
  if target.subscribes_to_notification?(key, notifiable: notifiable)
    store_notification(target, notifiable, key, options)
  end
end
```

This is the minimal change. The existing `subscribes_to_notification?` check stays in `generate_notification` (not moved to `notify`), and we extend it to also consider instance-level subscriptions.

#### `notify` - Add instance subscription targets

```ruby
def notify(target_type, notifiable, options = {})
  if options[:notify_later]
    notify_later(target_type, notifiable, options)
  else
    targets = notifiable.notification_targets(target_type, options[:pass_full_options] ? options : options[:key])
    # Merge instance subscription targets, deduplicate
    instance_targets = notifiable.instance_subscription_targets(target_type, options[:key])
    targets = merge_targets(targets, instance_targets)
    unless targets_empty?(targets)
      notify_all(targets, notifiable, options)
    end
  end
end
```

#### New helper: `merge_targets`

```ruby
def merge_targets(targets, instance_targets)
  return targets if instance_targets.blank?
  # Convert to array for deduplication
  all_targets = targets.respond_to?(:to_a) ? targets.to_a : Array(targets)
  (all_targets + instance_targets).uniq
end
```

### 5. Notifiable Concern (`models/concerns/notifiable.rb`)

Add `instance_subscription_targets`:

```ruby
def instance_subscription_targets(target_type, key = nil)
  key ||= default_notification_key
  target_class_name = target_type.to_s.to_model_name
  Subscription.where(
    notifiable_type: self.class.name,
    notifiable_id: self.id,
    key: key,
    subscribing: true
  ).where(target_type: target_class_name)
   .map(&:target)
   .compact
end
```

### 6. Subscription API (`apis/subscription_api.rb`)

Add `key_level_only` and `instance_level_only` scopes. No changes to existing subscribe/unsubscribe methods — they work on individual subscription records regardless of whether they're key-level or instance-level.

### 7. Controllers

Update `subscription_params` in `CommonController` to permit `notifiable_type` and `notifiable_id`.

Update `create` action to pass through notifiable params.

Update `find` action to support optional notifiable filtering.

## Async Path (`notify_later`)

The `notify_later` path serializes arguments and delegates to `NotifyJob`, which calls `notify` synchronously. Since our changes are in `notify` and `generate_notification`, the async path is automatically covered — no separate changes needed for `NotifyJob`.

## Migration Template

Update `lib/generators/templates/migrations/migration.rb` to include the new columns and updated index.

Provide a separate migration generator for existing installations:
`lib/generators/activity_notification/migration/add_notifiable_to_subscriptions_generator.rb`

## Backward Compatibility

- All existing key-level subscriptions have `notifiable_type = NULL` and `notifiable_id = NULL`
- `_subscribes_to_notification?` filters by `notifiable_type: nil`, so existing behavior is preserved
- `subscribes_to_notification?` without `notifiable:` parameter returns the same result as before
- `find_subscription(key)` without `notifiable:` returns key-level subscription as before

# Issue #202: Instance-Level Subscriptions - Tasks

## Task 1: Schema & Model Changes (ActiveRecord) ✅
- [x] Add `notifiable_type` (string, nullable) and `notifiable_id` (bigint, nullable) to subscriptions table in migration template
- [x] Update unique index from `[:target_type, :target_id, :key]` to `[:target_type, :target_id, :key, :notifiable_type, :notifiable_id]`
- [x] Add `belongs_to :notifiable, polymorphic: true, optional: true` to ActiveRecord Subscription model
- [x] Update uniqueness validation to `scope: [:target_type, :target_id, :notifiable_type, :notifiable_id]`
- [x] Add scopes: `key_level_only`, `instance_level_only`, `for_notifiable`
- [x] Update spec/rails_app migration

## Task 2: Schema & Model Changes (Mongoid) ✅
- [x] Add `belongs_to_polymorphic_xdb_record :notifiable` (optional) — creates notifiable_type/notifiable_id fields
- [x] Update uniqueness validation scope to include notifiable fields
- [x] Add scopes: `key_level_only`, `instance_level_only`, `for_notifiable`

## Task 3: Schema & Model Changes (Dynamoid) ✅
- [x] Add `belongs_to_composite_xdb_record :notifiable` (optional) — creates notifiable_key composite field
- [x] Uniqueness validation uses composite target_key (unchanged, Dynamoid-specific)

## Task 4: Subscriber Concern Updates ✅
- [x] Update `_subscribes_to_notification?` to filter by key-level only (notifiable_type: nil)
- [x] Add `_subscribes_to_notification_for_instance?(key, notifiable)` method
- [x] Update `_subscribes_to_notification_email?` to filter by key-level only
- [x] Update `_subscribes_to_optional_target?` to filter by key-level only
- [x] Update `find_subscription` to accept optional `notifiable:` keyword argument
- [x] Update `find_or_create_subscription` to accept optional `notifiable:` keyword argument
- [x] All methods handle Dynamoid composite key format

## Task 5: Target Concern Updates ✅
- [x] Update `subscribes_to_notification?` to accept optional `notifiable:` keyword and check both key-level and instance-level

## Task 6: Notification API Updates ✅
- [x] Update `generate_notification` to pass `notifiable` to `subscribes_to_notification?`
- [x] Update `notify` to merge instance subscription targets with deduplication
- [x] Add `merge_targets` private helper method

## Task 7: Notifiable Concern Updates ✅
- [x] Add `instance_subscription_targets(target_type, key)` method with ORM-aware queries

## Task 8: Controller & API Updates ✅
- [x] Update `subscription_params` in SubscriptionsController to permit `notifiable_type` and `notifiable_id`

## Task 9: Migration Generator ✅
- [x] Update `lib/generators/templates/migrations/migration.rb` for new installations
- [x] Create `add_notifiable_to_subscriptions` migration generator for existing installations

## Task 10: Tests ✅
- [x] Add instance-level subscription model tests (find, create, uniqueness)
- [x] Add `subscribes_to_notification?` tests with notifiable parameter
- [x] Add notification generation tests with instance subscriptions
- [x] Add `instance_subscription_targets` tests
- [x] Add deduplication tests for notify with instance subscription targets
- [x] Verify all existing tests still pass (1815 examples, 0 failures)

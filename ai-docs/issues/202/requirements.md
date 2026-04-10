# Issue #202: Instance-Level Subscriptions - Requirements

## Overview

Allow targets (e.g., users) to subscribe to notifications from a specific notifiable instance, not just by notification key. For example, a user can subscribe to comment notifications on Post #1 and Post #4 only, similar to GitHub's issue subscription model.

## Background

Currently, subscriptions are key-based only. A subscription record ties a target to a notification key (e.g., `comment.default`). When `subscribes_to_notification?(key)` is checked, it looks up the subscription by `(target, key)`. This is an all-or-nothing approach — you either subscribe to all notifications of a given key or none.

## Functional Requirements

### FR-1: Instance-Level Subscription Records
- A target MUST be able to create a subscription scoped to a specific notifiable instance (e.g., Post #1) and key.
- Instance-level subscriptions are stored in the same `subscriptions` table with additional `notifiable_type` and `notifiable_id` columns (nullable).
- Existing key-only subscriptions (where `notifiable_type` and `notifiable_id` are NULL) MUST continue to work unchanged.

### FR-2: Subscription Check During Notification Generation
- When generating a notification for a target, the system MUST check:
  1. Key-level subscription (existing behavior): Does the target subscribe to this key globally?
  2. Instance-level subscription (new): Does the target have an active instance-level subscription for this specific notifiable and key?
- A notification MUST be generated if EITHER the key-level subscription allows it OR an active instance-level subscription exists for the notifiable.

### FR-3: Instance Subscription Targets Discovery
- When `notify` is called for a notifiable, the system MUST also discover targets that have instance-level subscriptions for that specific notifiable, in addition to the targets returned by `notification_targets`.
- Duplicate targets (appearing in both `notification_targets` and instance subscriptions) MUST be deduplicated.

### FR-4: Async Path Support
- Instance-level subscriptions MUST work with both synchronous (`notify`) and asynchronous (`notify_later`) notification paths.

### FR-5: Multi-ORM Support
- Instance-level subscriptions MUST work with all three supported ORMs: ActiveRecord, Mongoid, and Dynamoid.

### FR-6: API and Controller Support
- The subscription API and controllers MUST support creating, finding, and managing instance-level subscriptions.
- The `create` action MUST accept optional `notifiable_type` and `notifiable_id` parameters.
- The `find` action MUST support finding subscriptions by key and optionally by notifiable.

### FR-7: Backward Compatibility
- All existing subscription behavior MUST remain unchanged.
- Existing subscriptions without notifiable fields MUST continue to function as key-level subscriptions.
- The unique constraint MUST be updated to accommodate both key-level and instance-level subscriptions.

## Non-Functional Requirements

### NFR-1: Performance
- Instance-level subscription checks MUST NOT introduce N+1 query problems.
- The implementation SHOULD batch-load instance subscriptions where possible.

### NFR-2: Test Coverage
- Test coverage MUST NOT decrease from the current level (~99.7%).
- New functionality MUST have comprehensive test coverage including edge cases.

### NFR-3: Migration
- A migration generator or template MUST be provided for adding the new columns.
- The migration MUST be safe to run on existing installations (additive only, nullable columns).

# Development Roadmap (post v2.6.0)

## Short-term

### Remove `jquery-rails` dependency
- `jquery-rails` is required in `lib/activity_notification/rails.rb` but Rails 7+ does not include jQuery by default
- The gem's views use jQuery for AJAX subscription management
- Migrate view JavaScript to Vanilla JS or Stimulus, then make `jquery-rails` optional
- This is the most impactful cleanup for modern Rails applications

### Review `swagger-blocks` dependency
- `swagger-blocks` is used for OpenAPI spec generation in API controllers
- Consider migrating to static YAML/JSON OpenAPI spec files or a more actively maintained library
- This would simplify the codebase and reduce runtime dependencies

## Medium-term

### Soft delete integration guide for notifiables
- Issue #140 requested `:nullify_notifiable` for `dependent_notifications`, but the design conflicts with Notification's `validates :notifiable, presence: true`
- Instead of modifying the gem, document integration patterns with `paranoia` or `discard` gems
- Add a section to Functions.md showing how soft-deleted notifiables work with notifications

### Configurable subscription association name
- Issue #161 requested renaming the `subscriptions` association to avoid conflicts with application models (e.g., billing subscriptions)
- Add an option to `acts_as_target` like `subscription_association_name: :notification_subscriptions`
- This avoids a breaking change while solving the conflict

## Long-term

### Turbo Streams support
- Current push notifications use Action Cable channels with custom JavaScript
- Rails 8 applications increasingly use Turbo Streams for real-time updates
- Add optional Turbo Streams broadcasting as an alternative to the current Action Cable channels

### Async notification batching
- Current `notify_later` serializes all targets into a single job
- For very large target sets (10,000+), split into chunked jobs that process targets in batches
- This would improve memory usage and job queue throughput

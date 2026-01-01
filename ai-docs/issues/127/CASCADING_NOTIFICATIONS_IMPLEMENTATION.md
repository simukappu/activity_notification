# Cascading Notifications Implementation

## Overview

The cascading notification feature enables sequential delivery of notifications through different channels based on read status, with configurable time delays between each step. This allows you to implement sophisticated notification escalation patterns, such as:

1. Send in-app notification
2. Wait 10 minutes → if not read, send Slack message
3. Wait another 10 minutes → if still not read, send email
4. Wait another 30 minutes → if still not read, send SMS

This feature is particularly useful for ensuring important notifications are not missed, while avoiding unnecessary interruptions when users have already engaged with earlier notification channels.

## Architecture

### Components

The cascading notification system consists of three main components:

1. **CascadingNotificationJob** (`app/jobs/activity_notification/cascading_notification_job.rb`)
   - ActiveJob-based job that handles individual cascade steps
   - Checks notification read status before triggering optional targets
   - Schedules subsequent cascade steps automatically
   - Handles errors gracefully with configurable error recovery

2. **CascadingNotificationApi** (`lib/activity_notification/apis/cascading_notification_api.rb`)
   - Module included in the Notification model
   - Provides `cascade_notify` method to initiate cascades
   - Validates cascade configurations
   - Manages cascade lifecycle

3. **Integration with Notification Model**
   - Extends ActiveRecord, Mongoid, and Dynamoid notification implementations
   - Seamlessly integrates with existing notification system
   - Compatible with all existing optional targets (Slack, Amazon SNS, email, etc.)

### How It Works

```
┌──────────────────────────────────────────────────────────────────┐
│ 1. notification.cascade_notify(config) called                   │
└───────────────────────┬──────────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────────┐
│ 2. Validation: Check config format, required parameters         │
└───────────────────────┬──────────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────────┐
│ 3. Schedule CascadingNotificationJob with first step delay      │
└───────────────────────┬──────────────────────────────────────────┘
                        │
                        ▼ (after delay)
┌──────────────────────────────────────────────────────────────────┐
│ 4. Job executes:                                                 │
│    - Find notification by ID                                     │
│    - Check if notification.opened? → YES: exit                   │
│    - Check if notification.opened? → NO: continue                │
└───────────────────────┬──────────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────────┐
│ 5. Trigger optional target for current step:                    │
│    - Find configured optional target                             │
│    - Check subscription status                                   │
│    - Call target.notify(notification, options)                   │
└───────────────────────┬──────────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────────┐
│ 6. Schedule next step if available:                             │
│    - Check if more steps exist in config                         │
│    - Schedule CascadingNotificationJob with next step delay      │
└──────────────────────────────────────────────────────────────────┘
```

## Configuration Options

### Cascade Configuration Structure

Each cascade is defined as an array of step configurations:

```ruby
cascade_config = [
  {
    delay: ActiveSupport::Duration,  # Required: Time to wait before this step
    target: Symbol or String,        # Required: Name of optional target (:slack, :email, etc.)
    options: Hash                    # Optional: Parameters to pass to the optional target
  },
  # ... more steps
]
```

### Cascade Method Options

The `cascade_notify` method accepts an optional second parameter for additional control:

```ruby
notification.cascade_notify(cascade_config, options)
```

Available options:
- `validate: Boolean` (default: `true`) - Whether to validate cascade configuration before starting
- `trigger_first_immediately: Boolean` (default: `false`) - Whether to trigger the first target immediately without waiting for the delay

## Usage Examples

### Basic Two-Step Cascade

Send a Slack notification after 10 minutes if unread, then email after another 10 minutes:

```ruby
# After creating a notification
notification = Notification.create!(
  target: user,
  notifiable: comment,
  key: 'comment.reply'
)

# Start the cascade
cascade_config = [
  { delay: 10.minutes, target: :slack },
  { delay: 10.minutes, target: :email }
]

notification.cascade_notify(cascade_config)
```

### Multi-Channel Escalation with Custom Options

Progressive escalation through multiple channels with custom parameters:

```ruby
cascade_config = [
  { 
    delay: 5.minutes, 
    target: :slack,
    options: { 
      channel: '#general',
      username: 'NotificationBot'
    }
  },
  { 
    delay: 10.minutes, 
    target: :slack,
    options: { 
      channel: '#urgent',
      username: 'UrgentBot'
    }
  },
  { 
    delay: 15.minutes, 
    target: :amazon_sns,
    options: { 
      subject: 'Urgent: Unread Notification',
      message_attributes: { priority: 'high' }
    }
  },
  { 
    delay: 30.minutes, 
    target: :email
  }
]

notification.cascade_notify(cascade_config)
```

### Immediate First Notification

Trigger the first target immediately, then cascade to others if still unread:

```ruby
cascade_config = [
  { delay: 5.minutes, target: :slack },  # Ignored delay, triggered immediately
  { delay: 10.minutes, target: :email }
]

notification.cascade_notify(cascade_config, trigger_first_immediately: true)
```

### Integration with Notification Creation

Combine cascade with standard notification creation:

```ruby
# In your notifiable model (e.g., Comment)
class Comment < ApplicationRecord
  acts_as_notifiable :users,
    targets: ->(comment, key) { ... },
    notifiable_path: :article_path
    
  # Optional: Define cascade configuration
  def notification_cascade_config
    [
      { delay: 10.minutes, target: :slack },
      { delay: 15.minutes, target: :email }
    ]
  end
end

# In your controller or service
comment = Comment.create!(params)
comment.notify(:users, key: 'comment.new')

# Start cascade for each notification
comment.notifications.each do |notification|
  notification.cascade_notify(comment.notification_cascade_config)
end
```

### Conditional Cascading

Apply different cascade strategies based on notification type or priority:

```ruby
def cascade_notification(notification)
  case notification.key
  when 'urgent.alert'
    # Aggressive escalation for urgent items
    cascade_config = [
      { delay: 2.minutes, target: :slack },
      { delay: 5.minutes, target: :email },
      { delay: 10.minutes, target: :sms }
    ]
  when 'comment.reply'
    # Gentle escalation for comments
    cascade_config = [
      { delay: 30.minutes, target: :slack },
      { delay: 1.hour, target: :email }
    ]
  else
    # Default escalation
    cascade_config = [
      { delay: 15.minutes, target: :slack },
      { delay: 30.minutes, target: :email }
    ]
  end
  
  notification.cascade_notify(cascade_config)
end
```

### Using with Asynchronous Notification Creation

When using `notify_later` (ActiveJob), cascade after notification creation:

```ruby
# Create notifications asynchronously
comment.notify_later(:users, key: 'comment.reply')

# Schedule cascade in a separate job or callback
class NotifyWithCascadeJob < ApplicationJob
  def perform(notifiable_type, notifiable_id, target_type, cascade_config)
    notifiable = notifiable_type.constantize.find(notifiable_id)
    
    # Get the notifications created for this notifiable
    notifications = ActivityNotification::Notification
      .where(notifiable: notifiable)
      .where(target_type: target_type.classify)
      .unopened_only
    
    # Apply cascade to each notification
    notifications.each do |notification|
      notification.cascade_notify(cascade_config)
    end
  end
end

# Usage
cascade_config = [
  { delay: 10.minutes, target: :slack },
  { delay: 10.minutes, target: :email }
]

NotifyWithCascadeJob.perform_later(
  'Comment',
  comment.id,
  'users',
  cascade_config
)
```

## Validation

### Automatic Validation

By default, `cascade_notify` validates the configuration before scheduling jobs:

```ruby
# This will raise ArgumentError if config is invalid
notification.cascade_notify(invalid_config)
# => ArgumentError: Invalid cascade configuration: Step 0 missing required :target parameter
```

### Manual Validation

You can validate a configuration before using it:

```ruby
result = notification.validate_cascade_config(cascade_config)

if result[:valid]
  notification.cascade_notify(cascade_config)
else
  Rails.logger.error("Invalid cascade config: #{result[:errors].join(', ')}")
end
```

### Skipping Validation

For performance-critical scenarios where you're confident in your configuration:

```ruby
notification.cascade_notify(cascade_config, validate: false)
```

## Error Handling

### Graceful Error Recovery

The cascading notification system respects the global `rescue_optional_target_errors` configuration:

```ruby
# In config/initializers/activity_notification.rb
ActivityNotification.configure do |config|
  config.rescue_optional_target_errors = true  # Default
end
```

When enabled:
- Errors in optional targets are caught and logged
- The cascade continues to subsequent steps
- Error information is returned in the job result

When disabled:
- Errors propagate and halt the cascade
- Useful for debugging and development

### Example Error Handling

```ruby
# In your optional target
class CustomOptionalTarget < ActivityNotification::OptionalTarget::Base
  def notify(notification, options = {})
    raise StandardError, "API unavailable" if service_down?
    
    # ... normal notification logic
  end
end

# With rescue_optional_target_errors = true:
# - Error is logged
# - Returns { custom: #<StandardError: API unavailable> }
# - Next cascade step is still scheduled

# With rescue_optional_target_errors = false:
# - Error propagates
# - Job fails
# - Next cascade step is NOT scheduled
```

## Read Status Checking

The cascade automatically stops when a notification is read at any point:

```ruby
# Start cascade
notification.cascade_notify(cascade_config)

# User opens notification after 5 minutes
notification.open!

# Subsequent cascade steps will detect opened? == true and exit immediately
# No further optional targets will be triggered
```

## Performance Considerations

### Job Queue Configuration

Cascading notifications use the configured ActiveJob queue:

```ruby
# In config/initializers/activity_notification.rb
ActivityNotification.configure do |config|
  config.active_job_queue = :notifications  # or :default, :high_priority, etc.
end
```

For high-volume applications, consider using a dedicated queue:

```ruby
config.active_job_queue = :cascading_notifications
```

### Database Queries

Each cascade step performs:
1. One `SELECT` to find the notification
2. One check of the `opened_at` field
3. Optional queries for target and notifiable associations

For optimal performance:
- Ensure `notifications.id` is indexed (primary key)
- Ensure `notifications.opened_at` is indexed
- Consider using database connection pooling

### Memory Usage

Each scheduled job holds:
- Notification ID (Integer)
- Cascade configuration (Array of Hashes)
- Current step index (Integer)

Total memory footprint per job: ~1-2 KB depending on configuration size

## Limitations and Known Issues

### 1. No Built-in Cascade State Tracking

The current implementation doesn't maintain explicit state about active cascades. The `cascade_in_progress?` method returns `false` by default.

**Workaround**: If you need to track cascade state, consider:
- Adding a custom field to your notification model
- Using Redis to store cascade state
- Querying the job queue (adapter-specific)

### 2. Cascade Configuration Not Persisted

Cascade configurations are passed as job arguments and not stored in the database.

**Implication**: You cannot query or modify a running cascade. Once started, it will complete its configured steps or stop when the notification is read.

**Workaround**: Store cascade configuration in notification `parameters` if needed for auditing:

```ruby
notification.update(parameters: notification.parameters.merge(
  cascade_config: cascade_config
))
notification.cascade_notify(cascade_config)
```

### 3. Time Drift

Scheduled jobs may execute slightly later than the configured delay due to queue processing time.

**Mitigation**: The system uses `set(wait: delay)` which is accurate to within seconds for most ActiveJob adapters.

### 4. Deleted Notifications

If a notification is deleted while cascade jobs are scheduled, subsequent jobs will gracefully exit with `nil` return value.

### 5. Optional Target Availability

Cascades assume optional targets are configured on the notifiable model. If a target is removed from configuration after cascade starts, the job will return `:not_configured` status.

## Testing

### Unit Testing

```ruby
RSpec.describe "Cascading Notifications" do
  it "schedules cascade jobs" do
    notification = create(:notification)
    cascade_config = [
      { delay: 10.minutes, target: :slack }
    ]
    
    expect {
      notification.cascade_notify(cascade_config)
    }.to have_enqueued_job(ActivityNotification::CascadingNotificationJob)
  end
end
```

### Integration Testing

```ruby
RSpec.describe "Cascading Notifications Integration" do
  it "executes full cascade when unread" do
    notification = create(:notification)
    
    # Configure and start cascade
    cascade_config = [
      { delay: 10.minutes, target: :slack },
      { delay: 10.minutes, target: :email }
    ]
    notification.cascade_notify(cascade_config)
    
    # Simulate time passing
    travel_to(10.minutes.from_now) do
      # Perform first job
      ActiveJob::Base.queue_adapter.enqueued_jobs.first[:job].constantize.perform_now(...)
      
      # Verify second job was scheduled
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(1)
    end
  end
end
```

### Testing with Time Travel

Use `travel_to` or `Timecop` to test time-delayed behavior:

```ruby
it "stops cascade when notification is read" do
  notification = create(:notification)
  cascade_config = [
    { delay: 5.minutes, target: :slack },
    { delay: 10.minutes, target: :email }
  ]
  
  notification.cascade_notify(cascade_config)
  
  # First step executes
  travel_to(5.minutes.from_now) do
    perform_enqueued_jobs
  end
  
  # User reads notification
  notification.open!
  
  # Second step should exit without triggering
  travel_to(15.minutes.from_now) do
    job_instance = CascadingNotificationJob.new
    result = job_instance.perform(notification.id, cascade_config, 1)
    expect(result).to be_nil
  end
end
```

## Migration Guide

### For Existing Applications

1. **Update notification models**: No changes needed - the API is automatically included

2. **Configure optional targets**: Ensure your notifiable models have optional targets configured

3. **Add cascade configurations**: Define cascade configs where needed

4. **Test thoroughly**: Use the test suite to verify cascade behavior

5. **Monitor job queue**: Watch for job buildup or delays in processing

### Example Migration

**Before** (manual escalation):
```ruby
# Controller
comment.notify(:users)

# Separate delayed job for escalation
EscalationJob.set(wait: 10.minutes).perform_later(comment.id)
```

**After** (cascading notifications):
```ruby
# Controller
comment.notify(:users)

# Start cascade immediately
comment.notifications.each do |notification|
  notification.cascade_notify([
    { delay: 10.minutes, target: :slack },
    { delay: 10.minutes, target: :email }
  ])
end
```

## Best Practices

### 1. Choose Appropriate Delays

- **Too short**: May annoy users with rapid escalation
- **Too long**: Users may miss important notifications
- **Recommended**: Start with 10-15 minute intervals, adjust based on user behavior

### 2. Limit Cascade Depth

- Keep cascades to 3-4 steps maximum
- Each additional step increases job queue load
- Consider user experience - excessive notifications are counterproductive

### 3. Use Specific Optional Target Options

```ruby
# Good: Specific, actionable messages
{ 
  delay: 10.minutes, 
  target: :slack,
  options: { 
    channel: '#urgent-alerts',
    message: 'You have an unread notification requiring attention'
  }
}

# Avoid: Generic messages without context
{ delay: 10.minutes, target: :slack }
```

### 4. Handle Subscription Status

Respect user preferences by ensuring optional targets check subscription:

```ruby
# In your optional target
def notify(notification, options = {})
  return unless notification.optional_target_subscribed?(:slack)
  # ... notification logic
end
```

### 5. Monitor and Alert

Set up monitoring for:
- Cascade job success/failure rates
- Average time between cascade steps
- Percentage of cascades that complete vs. stop early
- User engagement after cascade notifications

### 6. Document Your Cascade Strategies

```ruby
# Good: Clear documentation of strategy
# Urgent notifications: Escalate quickly through Slack → SMS → Phone
# Regular notifications: Gentle escalation through in-app → Email

URGENT_CASCADE = [
  { delay: 2.minutes, target: :slack, options: { channel: '#urgent' } },
  { delay: 5.minutes, target: :sms },
  { delay: 10.minutes, target: :phone }
].freeze

REGULAR_CASCADE = [
  { delay: 30.minutes, target: :email }
].freeze
```

## Architecture Decisions

### Why ActiveJob?

- **Standard Rails integration**: Works with any ActiveJob adapter
- **Persistence**: Job state is maintained by the adapter
- **Retries**: Built-in retry mechanisms for failed jobs
- **Monitoring**: Compatible with job monitoring tools

### Why Not Use Scheduled Jobs?

The cascade could have been implemented with cron-like scheduled jobs that periodically check for unread notifications. However:

- **Scalability**: Per-notification jobs scale better than scanning all notifications
- **Precision**: Exact delays per notification rather than polling intervals
- **Resource usage**: Only creates jobs for cascading notifications, not all notifications

### Why Pass Configuration as Job Arguments?

Cascade configuration is passed to jobs rather than stored in the database because:

- **Simplicity**: No schema changes required
- **Flexibility**: Configuration can be programmatically generated
- **Immutability**: Cascade behavior is fixed once started (predictable)

Trade-off: Cannot modify running cascades (acceptable for most use cases)

### Why Check Read Status in Job?

The job checks `notification.opened?` rather than relying on cancellation because:

- **Reliability**: Cancelling jobs is adapter-specific and not universally supported
- **Simplicity**: Single query is cheaper than job cancellation logic
- **Race conditions**: Avoids race between reading notification and cancelling jobs

## Future Enhancements

Potential improvements for future versions:

1. **Cascade Templates**: Pre-defined cascade strategies
2. **Dynamic Delays**: Calculate delays based on notification priority or time of day
3. **Cascade Analytics**: Built-in tracking of cascade effectiveness
4. **Cascade Cancellation**: Explicit API to cancel running cascades
5. **Batch Cascading**: Apply cascades to multiple notifications efficiently
6. **Cascade State Tracking**: Persist cascade state in database or Redis
7. **Custom Conditions**: Beyond read status (e.g., user online status)
8. **Cascade Hooks**: Callbacks for cascade start, step, complete events

## Troubleshooting

### Cascade Not Starting

**Symptom**: Calling `cascade_notify` returns `false`

**Possible causes**:
1. Notification already opened: Check `notification.opened?`
2. Empty cascade config: Verify config is not `[]`
3. ActiveJob not available: Check Rails environment
4. Validation failing: Try with `validate: false` to see if config is invalid

### Jobs Not Executing

**Symptom**: Jobs scheduled but not running

**Check**:
1. ActiveJob adapter is running (e.g., Sidekiq, Delayed Job)
2. Queue name matches: `ActivityNotification.config.active_job_queue`
3. Job is in correct queue: Inspect `ActiveJob::Base.queue_adapter`

### Cascade Not Stopping When Read

**Symptom**: Notifications keep sending after user reads

**Check**:
1. `notification.open!` is being called correctly
2. `opened_at` field is being set in database
3. Job is checking the correct notification ID
4. Database transactions are committing properly

### Optional Target Not Triggered

**Symptom**: Jobs execute but target not notified

**Check**:
1. Optional target is configured on notifiable model
2. Target name matches exactly (`:slack` vs `'slack'`)
3. Subscription status: `notification.optional_target_subscribed?(target_name)`
4. Optional target's `notify` method is implemented correctly

## Support and Contributing

For issues, questions, or contributions related to cascading notifications:

1. Check existing GitHub issues
2. Review test files for usage examples
3. Consult activity_notification documentation for optional target configuration
4. Create detailed bug reports with reproduction steps

## License

The cascading notification feature follows the same MIT License as activity_notification.

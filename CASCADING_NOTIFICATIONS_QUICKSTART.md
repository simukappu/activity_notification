# Cascading Notifications - Quick Start Guide

## What Are Cascading Notifications?

Cascading notifications allow you to automatically send notifications through multiple channels (Slack, Email, SMS, etc.) with time delays, but only if the user hasn't already read the notification.

**Example Flow:**
1. User gets an in-app notification
2. ⏱️ Wait 10 minutes → Still unread? Send Slack message
3. ⏱️ Wait 10 more minutes → Still unread? Send Email
4. ⏱️ Wait 30 more minutes → Still unread? Send SMS

If the user reads the notification at any point, the cascade stops automatically!

## Installation

The cascading notification feature is already integrated into activity_notification. No additional installation needed!

## Quick Examples

### Example 1: Simple Two-Step Cascade

```ruby
# Create a notification
notification = Notification.create!(
  target: user,
  notifiable: comment,
  key: 'comment.reply'
)

# Setup cascade: Slack after 10 min, Email after another 10 min
cascade_config = [
  { delay: 10.minutes, target: :slack },
  { delay: 10.minutes, target: :email }
]

# Start the cascade
notification.cascade_notify(cascade_config)
```

### Example 2: Immediate First Notification

```ruby
# Send Slack immediately, then email if still unread
cascade_config = [
  { delay: 5.minutes, target: :slack },
  { delay: 10.minutes, target: :email }
]

notification.cascade_notify(cascade_config, trigger_first_immediately: true)
```

### Example 3: With Custom Options

```ruby
cascade_config = [
  { 
    delay: 5.minutes, 
    target: :slack,
    options: { channel: '#urgent' }
  },
  { 
    delay: 10.minutes, 
    target: :email
  }
]

notification.cascade_notify(cascade_config)
```

### Example 4: Integration with Notification Creation

```ruby
# In your controller
comment = Comment.create!(comment_params)

# Create notifications
comment.notify(:users, key: 'comment.new')

# Add cascade to all created notifications
comment.notifications.each do |notification|
  cascade_config = [
    { delay: 10.minutes, target: :slack },
    { delay: 30.minutes, target: :email }
  ]
  notification.cascade_notify(cascade_config)
end
```

## Configuration Format

Each step in the cascade requires:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `delay` | Duration | Yes | How long to wait (e.g., `10.minutes`, `1.hour`) |
| `target` | Symbol/String | Yes | Optional target name (`:slack`, `:email`, etc.) |
| `options` | Hash | No | Custom options to pass to the target |

## Common Patterns

### Urgent Notifications (Fast Escalation)

```ruby
URGENT_CASCADE = [
  { delay: 2.minutes, target: :slack },
  { delay: 5.minutes, target: :email },
  { delay: 10.minutes, target: :sms }
].freeze
```

### Normal Notifications (Gentle Escalation)

```ruby
NORMAL_CASCADE = [
  { delay: 30.minutes, target: :slack },
  { delay: 1.hour, target: :email }
].freeze
```

### Reminder Pattern (Long Delays)

```ruby
REMINDER_CASCADE = [
  { delay: 1.day, target: :email },
  { delay: 3.days, target: :email },
  { delay: 1.week, target: :email }
].freeze
```

## Prerequisites

Before using cascading notifications, make sure:

1. **Optional targets are configured** on your notifiable models
2. **ActiveJob is configured** (default in Rails)
3. **Job queue is running** (Sidekiq, Delayed Job, etc.)

Example optional target configuration:

```ruby
class Comment < ApplicationRecord
  require 'activity_notification/optional_targets/slack'
  
  acts_as_notifiable :users,
    targets: ->(comment, key) { ... },
    optional_targets: {
      ActivityNotification::OptionalTarget::Slack => {
        webhook_url: ENV['SLACK_WEBHOOK_URL'],
        channel: '#notifications'
      }
    }
end
```

## Testing

### Basic Test

```ruby
it "schedules cascade jobs" do
  notification = create(:notification)
  
  cascade_config = [
    { delay: 10.minutes, target: :slack }
  ]
  
  expect {
    notification.cascade_notify(cascade_config)
  }.to have_enqueued_job(ActivityNotification::CascadingNotificationJob)
end
```

### Testing with Time Travel

```ruby
it "stops cascade when notification is read" do
  notification = create(:notification)
  
  cascade_config = [
    { delay: 10.minutes, target: :slack },
    { delay: 10.minutes, target: :email }
  ]
  
  notification.cascade_notify(cascade_config)
  
  # Mark as read before second step
  travel_to(15.minutes.from_now) do
    notification.open!
    
    # Execute job - should exit without sending
    job = CascadingNotificationJob.new
    result = job.perform(notification.id, cascade_config, 1)
    expect(result).to be_nil
  end
end
```

## Validation

Cascade configurations are automatically validated:

```ruby
# Valid
notification.cascade_notify([
  { delay: 10.minutes, target: :slack }
])

# Invalid - will raise ArgumentError
notification.cascade_notify([
  { target: :slack }  # Missing delay
])
# => ArgumentError: Invalid cascade configuration: Step 0 missing :delay parameter

# Skip validation (not recommended)
notification.cascade_notify(config, validate: false)
```

## Troubleshooting

### Cascade Not Starting

Check:
- Is notification already opened? `notification.opened?`
- Is config valid? `notification.validate_cascade_config(config)`
- Is ActiveJob running?

### Jobs Not Executing

Check:
- Job queue is running (Sidekiq, Delayed Job, etc.)
- Correct queue name: `ActivityNotification.config.active_job_queue`
- Jobs in queue: `ActiveJob::Base.queue_adapter.enqueued_jobs`

### Target Not Triggered

Check:
- Optional target is configured on notifiable model
- Target name matches (`:slack` not `'Slack'`)
- User is subscribed: `notification.optional_target_subscribed?(:slack)`

## Options Reference

### cascade_notify Options

```ruby
notification.cascade_notify(cascade_config, options)
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `validate` | Boolean | `true` | Validate config before starting |
| `trigger_first_immediately` | Boolean | `false` | Trigger first target without delay |

## Best Practices

### ✅ DO

- Keep cascades to 3-4 steps maximum
- Use meaningful delays (10-30 minutes for urgent, 1+ hours for normal)
- Document your cascade strategies
- Test cascade behavior with time travel
- Respect user subscription preferences

### ❌ DON'T

- Create cascades with too many steps
- Use very short delays (< 2 minutes) for non-urgent notifications
- Skip validation in production
- Forget to configure optional targets
- Ignore error handling

## Examples by Use Case

### E-commerce Order Updates

```ruby
# Order placed - immediate confirmation, then follow-ups if unread
order_notification = order.notifications.first

order_notification.cascade_notify([
  { delay: 2.hours, target: :email },   # "Did you see your order confirmation?"
  { delay: 1.day, target: :sms }        # "Your order is on the way!"
], trigger_first_immediately: true)     # Immediate in-app notification
```

### Social Media Interactions

```ruby
# Someone replied to your comment
notification.cascade_notify([
  { delay: 30.minutes, target: :slack },
  { delay: 2.hours, target: :email }
])
```

### Task Management / Reminders

```ruby
# Task due date approaching
notification.cascade_notify([
  { delay: 1.day, target: :email },
  { delay: 3.hours, target: :slack },
  { delay: 1.hour, target: :sms }
])
```

### Critical System Alerts

```ruby
# System error or security alert
notification.cascade_notify([
  { delay: 1.minute, target: :slack, options: { channel: '#alerts' } },
  { delay: 5.minutes, target: :email },
  { delay: 10.minutes, target: :sms }
], trigger_first_immediately: true)
```

## Advanced Usage

### Conditional Cascading

```ruby
def apply_cascade(notification)
  case notification.notifiable
  when CriticalAlert
    notification.cascade_notify(URGENT_CASCADE)
  when Comment
    notification.cascade_notify(NORMAL_CASCADE)
  when Reminder
    notification.cascade_notify(REMINDER_CASCADE)
  end
end
```

### Dynamic Configuration

```ruby
def cascade_for_user(user, base_delay: 10.minutes)
  # Adjust delays based on user preferences
  multiplier = user.notification_urgency_preference || 1.0
  
  [
    { delay: base_delay * multiplier, target: :slack },
    { delay: base_delay * 2 * multiplier, target: :email }
  ]
end
```

## API Reference

### Main Methods

#### `cascade_notify(cascade_config, options = {})`

Starts a cascading notification sequence.

**Returns:** `true` if cascade started, `false` otherwise

#### `validate_cascade_config(cascade_config)`

Validates a cascade configuration.

**Returns:** Hash with `:valid` (Boolean) and `:errors` (Array) keys

#### `cascade_in_progress?`

Checks if a cascade is currently running (always returns `false` in current implementation).

**Returns:** Boolean

## Need More Help?

- 📖 Full Documentation: [CASCADING_NOTIFICATIONS_IMPLEMENTATION.md](./CASCADING_NOTIFICATIONS_IMPLEMENTATION.md)
- 🧪 Test Examples: `spec/jobs/cascading_notification_job_spec.rb`, `spec/concerns/cascading_notification_api_spec.rb`, `spec/integration/cascading_notifications_spec.rb`
- 💬 GitHub Issues: Report bugs or ask questions

## Summary

Cascading notifications make it easy to ensure important notifications are seen without being intrusive. Start with simple two-step cascades and adjust based on user behavior and feedback.

**Remember:** The cascade automatically stops when the user reads the notification, so you're never sending unnecessary notifications! 🎉

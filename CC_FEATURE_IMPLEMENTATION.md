# CC (Carbon Copy) Feature Implementation

## Overview

The CC (Carbon Copy) functionality has been added to the activity_notification gem's email notification system. This feature allows email notifications to be sent with additional CC recipients, following the same pattern as existing email header fields like `from`, `reply_to`, and `to`.

CC recipients can be configured at three levels:
1. **Global configuration** - Set a default CC for all notifications via the gem's configuration file
2. **Target model** - Define CC recipients at the target level (e.g., User, Admin)
3. **Notifiable model** - Override CC per notification type in the notifiable model

## Implementation Details

### Files Modified

1. **lib/activity_notification/config.rb**
   - Added `mailer_cc` configuration attribute to allow global CC configuration
   - Supports String, Array, or Proc values for flexible CC recipient configuration
   
2. **lib/activity_notification/mailers/helpers.rb**
   - Added `cc: :mailer_cc` to the email headers processing loop in the `headers_for` method
   - Updated the `mailer_cc` helper method to check configuration when target doesn't define mailer_cc
   - Updated the header value resolution logic to properly handle the `mailer_cc` method which takes a target parameter instead of a key parameter

3. **lib/generators/templates/activity_notification.rb**
   - Added configuration example and documentation for `config.mailer_cc`

### Key Features

- **Three-Level Configuration**: CC can be configured at the global level (gem configuration), target level (model), or notification level (per-notification type)
- **Flexible CC Recipients**: CC can be specified as a single email address (String), multiple email addresses (Array), or dynamic via Proc
- **Optional Implementation**: All CC configuration is optional - if not defined, no CC recipients will be added
- **Override Support**: Like other email headers, CC can be overridden per notification using the `overriding_notification_email_cc` method in the notifiable model
- **Consistent Pattern**: Follows the same implementation pattern as existing email headers (`from`, `reply_to`, `to`)

## Usage Guide

### Method 1: Configure CC Globally (New Feature)

Set a default CC for all notification emails in your initializer:

```ruby
# config/initializers/activity_notification.rb
ActivityNotification.configure do |config|
  # Single CC recipient for all notifications
  config.mailer_cc = 'admin@example.com'
  
  # OR multiple CC recipients
  config.mailer_cc = ['admin@example.com', 'support@example.com']
  
  # OR dynamic CC based on notification key
  config.mailer_cc = ->(key) {
    if key.include?('urgent')
      ['urgent@example.com', 'manager@example.com']
    else
      'admin@example.com'
    end
  }
end
```

### Method 2: Define `mailer_cc` in Your Target Model

Add a `mailer_cc` method to your target model (e.g., User, Admin) to specify CC recipients for that target. This overrides the global configuration:

```ruby
class User < ApplicationRecord
  acts_as_target
  
  # Return a single CC email address
  def mailer_cc
    "admin@example.com"
  end
  
  # OR return multiple CC email addresses
  def mailer_cc
    ["admin@example.com", "manager@example.com"]
  end
  
  # OR conditionally return CC addresses
  def mailer_cc
    return nil unless self.team_lead.present?
    self.team_lead.email
  end
end
```

### Method 3: Override CC Per Notification Type

For more granular control, implement `overriding_notification_email_cc` in your notifiable model to set CC based on the notification type. This has the highest priority:

```ruby
class Article < ApplicationRecord
  acts_as_notifiable
  
  def overriding_notification_email_cc(target, key)
    case key
    when 'article.commented'
      # CC the article author on comment notifications
      self.author.email
    when 'article.published'
      # CC multiple recipients for published articles
      ["editor@example.com", "marketing@example.com"]
    else
      nil # Use target's mailer_cc or global config
    end
  end
end
```

### Method 4: Combine All Approaches

You can combine all approaches - the priority order is: notification override > target method > global configuration:

```ruby
# config/initializers/activity_notification.rb
ActivityNotification.configure do |config|
  # Global default for all notifications
  config.mailer_cc = "support@example.com"
end

class User < ApplicationRecord
  acts_as_target
  
  # Override global config for this target
  def mailer_cc
    "admin@example.com"
  end
end

class Comment < ApplicationRecord
  acts_as_notifiable
  
  # Override both global config and target method for specific notifications
  def overriding_notification_email_cc(target, key)
    if key == 'comment.urgent'
      ["urgent@example.com", "manager@example.com"]
    else
      nil # Falls back to target.mailer_cc, then global config
    end
  end
end
```

## Examples

### Example 1: Global Configuration with Static CC

```ruby
# config/initializers/activity_notification.rb
ActivityNotification.configure do |config|
  config.mailer_cc = "admin@example.com"
end

# All notification emails will include:
# To: user@example.com
# CC: admin@example.com
```

### Example 2: Global Configuration with Multiple CC Recipients

```ruby
# config/initializers/activity_notification.rb
ActivityNotification.configure do |config|
  config.mailer_cc = ["supervisor@example.com", "hr@example.com"]
end

# All notification emails will include:
# To: user@example.com
# CC: supervisor@example.com, hr@example.com
```

### Example 3: Dynamic Global CC Based on Notification Key

```ruby
# config/initializers/activity_notification.rb
ActivityNotification.configure do |config|
  config.mailer_cc = ->(key) {
    case key
    when /urgent/
      ["urgent@example.com", "manager@example.com"]
    when /comment/
      "moderation@example.com"
    else
      "admin@example.com"
    end
  }
end
```

### Example 4: Target-Level Static CC

```ruby
class User < ApplicationRecord
  acts_as_target
  
  def mailer_cc
    "admin@example.com"
  end
end

# When a notification is sent, the email will include:
# To: user@example.com
# CC: admin@example.com
```

### Example 5: Target-Level Multiple CC Recipients

```ruby
class User < ApplicationRecord
  acts_as_target
  
  def mailer_cc
    ["supervisor@example.com", "hr@example.com"]
  end
end

# Email will include:
# To: user@example.com
# CC: supervisor@example.com, hr@example.com
```

### Example 6: Dynamic CC Based on User Attributes

```ruby
class User < ApplicationRecord
  acts_as_target
  belongs_to :department
  
  def mailer_cc
    cc_list = []
    cc_list << self.manager.email if self.manager.present?
    cc_list << self.department.email if self.department.present?
    cc_list.presence # Returns nil if empty, otherwise returns the array
  end
end
```

### Example 7: Override CC Per Notification

```ruby
class Article < ApplicationRecord
  acts_as_notifiable
  belongs_to :author
  
  def overriding_notification_email_cc(target, key)
    case key
    when 'article.new_comment'
      # Notify the article author when someone comments
      self.author.email
    when 'article.shared'
      # Notify multiple stakeholders when article is shared
      [self.author.email, "marketing@example.com"]
    when 'article.flagged'
      # Notify moderation team
      ["moderation@example.com", "admin@example.com"]
    else
      nil
    end
  end
end
```

### Example 8: Conditional CC Based on Target and Key

```ruby
class Post < ApplicationRecord
  acts_as_notifiable
  
  def overriding_notification_email_cc(target, key)
    cc_list = []
    
    # Always CC the post owner
    cc_list << self.user.email if self.user.present?
    
    # For urgent notifications, CC administrators
    if key.include?('urgent')
      cc_list += User.where(role: 'admin').pluck(:email)
    end
    
    # For specific users, CC their team lead
    if target.team_lead.present?
      cc_list << target.team_lead.email
    end
    
    cc_list.uniq.presence
  end
end
```

## Technical Details

### Resolution Order

The CC recipient(s) are resolved in the following priority order:

1. **Override Method** (Highest Priority): If the notifiable model has `overriding_notification_email_cc(target, key)` defined and returns a non-nil value, that value is used
2. **Target Method**: If no override is provided, the target's `mailer_cc` method is called (if it exists)
3. **Global Configuration**: If the target doesn't have a `mailer_cc` method, the global `config.mailer_cc` setting is used (if configured)
4. **No CC** (Default): If none of the above are defined or all return nil, no CC header is added to the email

### Return Value Format

Both the `mailer_cc` method and `config.mailer_cc` configuration can return:
- **String**: A single email address (e.g., `"admin@example.com"`)
- **Array<String>**: Multiple email addresses (e.g., `["admin@example.com", "manager@example.com"]`)
- **Proc**: A lambda/proc that takes the notification key and returns a String, Array, or nil (e.g., `->(key) { key.include?('urgent') ? 'urgent@example.com' : nil }`)
- **nil**: No CC recipients (CC header will not be added to the email)

### Implementation Pattern

The CC feature follows the same pattern as other email headers in the gem:

```ruby
# In headers_for method
{
  subject: :subject_for,
  from: :mailer_from,
  reply_to: :mailer_reply_to,
  cc: :mailer_cc,        # <-- New CC support
  message_id: nil
}.each do |header_name, default_method|
  # Check for override method in notifiable
  overridding_method_name = "overriding_notification_email_#{header_name}"
  if notifiable.respond_to?(overridding_method_name)
    use_override_value
  elsif default_method
    use_default_method
  end
end
```

## Testing

To test the CC functionality in your application:

```ruby
# RSpec example
RSpec.describe "Notification emails with CC" do
  let(:user) { create(:user) }
  let(:notification) { create(:notification, target: user) }
  
  before do
    # Define mailer_cc for the test
    allow(user).to receive(:mailer_cc).and_return("admin@example.com")
  end
  
  it "includes CC recipient in email" do
    mail = ActivityNotification::Mailer.send_notification_email(notification)
    expect(mail.cc).to include("admin@example.com")
  end
  
  it "supports multiple CC recipients" do
    allow(user).to receive(:mailer_cc).and_return(["admin@example.com", "manager@example.com"])
    mail = ActivityNotification::Mailer.send_notification_email(notification)
    expect(mail.cc).to eq(["admin@example.com", "manager@example.com"])
  end
  
  it "does not include CC header when nil" do
    allow(user).to receive(:mailer_cc).and_return(nil)
    mail = ActivityNotification::Mailer.send_notification_email(notification)
    expect(mail.cc).to be_nil
  end
end
```

## Backward Compatibility

This feature is **fully backward compatible**:
- Existing applications without `mailer_cc` defined will continue to work exactly as before
- No CC header will be added to emails unless explicitly configured
- No database migrations or configuration changes are required
- The implementation gracefully handles cases where `mailer_cc` is not defined

## Best Practices

1. **Return nil for no CC**: If you don't want CC recipients, return `nil` rather than an empty array or empty string
2. **Validate email addresses**: Ensure CC recipients are valid email addresses to avoid mail delivery issues
3. **Avoid excessive CC**: Be mindful of privacy and avoid CCing too many recipients
4. **Use override for specific cases**: Use `overriding_notification_email_cc` for notification-specific CC logic
5. **Keep it simple**: Use the target's `mailer_cc` method for consistent CC across all notifications

## Related Methods

The CC feature works alongside these existing email configuration methods:

- `mailer_to` - Primary recipient email address (required)
- `mailer_from` - Sender email address
- `mailer_reply_to` - Reply-to email address
- `mailer_cc` - Carbon copy recipients (new)

All of these can be overridden using the `overriding_notification_email_*` pattern in the notifiable model.

## Summary

The CC functionality seamlessly integrates with the existing activity_notification email system, providing a flexible and powerful way to add carbon copy recipients to notification emails. Whether you need static CC addresses, dynamic recipients based on user attributes, or notification-specific CC logic, this implementation supports all these use cases while maintaining backward compatibility with existing code.

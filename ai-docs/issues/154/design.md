# Design: Email Attachments Support (#154)

## Overview

Follows the same pattern as the CC feature (#107). Three-level configuration, no database changes, integrates into existing mailer helpers.

## Attachment Specification Format

```ruby
{
  filename: String,        # Required
  content:  String/Binary, # Either :content or :path required
  path:     String,        # Either :content or :path required
  mime_type: String        # Optional, inferred from filename if omitted
}
```

## Configuration Levels

### 1. Global (`config.mailer_attachments`)

```ruby
# Single attachment
config.mailer_attachments = { filename: 'terms.pdf', path: Rails.root.join('public', 'terms.pdf') }

# Multiple attachments
config.mailer_attachments = [
  { filename: 'logo.png', path: Rails.root.join('app/assets/images/logo.png') },
  { filename: 'terms.pdf', content: generate_pdf }
]

# Dynamic (Proc receives notification key)
config.mailer_attachments = ->(key) {
  key.include?('invoice') ? { filename: 'invoice.pdf', content: generate_invoice } : nil
}
```

### 2. Target (`target.mailer_attachments`)

```ruby
class User < ActiveRecord::Base
  acts_as_target email: :email

  def mailer_attachments
    admin? ? { filename: 'admin_guide.pdf', path: '/path/to/guide.pdf' } : nil
  end
end
```

### 3. Notifiable Override (`notifiable.overriding_notification_email_attachments`)

```ruby
class Invoice < ActiveRecord::Base
  acts_as_notifiable :users, targets: -> { ... }

  def overriding_notification_email_attachments(target, key)
    { filename: "invoice_#{id}.pdf", content: generate_pdf }
  end
end
```

## Implementation

### config.rb

Add `mailer_attachments` attribute, initialize to `nil`.

### mailers/helpers.rb

#### New method: `mailer_attachments(target)`

Same pattern as `mailer_cc(target)`:

```ruby
def mailer_attachments(target)
  if target.respond_to?(:mailer_attachments)
    target.mailer_attachments
  elsif ActivityNotification.config.mailer_attachments.present?
    if ActivityNotification.config.mailer_attachments.is_a?(Proc)
      key = @notification ? @notification.key : nil
      ActivityNotification.config.mailer_attachments.call(key)
    else
      ActivityNotification.config.mailer_attachments
    end
  else
    nil
  end
end
```

#### New method: `resolve_attachments(key)`

Resolve with notifiable override priority:

```ruby
def resolve_attachments(key)
  if @notification&.notifiable&.respond_to?(:overriding_notification_email_attachments) &&
     @notification.notifiable.overriding_notification_email_attachments(@target, key).present?
    @notification.notifiable.overriding_notification_email_attachments(@target, key)
  else
    mailer_attachments(@target)
  end
end
```

#### New method: `process_attachments(mail_obj, specs)`

```ruby
def process_attachments(mail_obj, specs)
  return if specs.blank?
  Array(specs).each do |spec|
    next if spec.blank?
    validate_attachment_spec!(spec)
    content = spec[:content] || File.read(spec[:path])
    options = { content: content }
    options[:mime_type] = spec[:mime_type] if spec[:mime_type]
    mail_obj.attachments[spec[:filename]] = options
  end
end
```

#### Modified: `headers_for`

Add attachment resolution, store in headers:

```ruby
attachment_specs = resolve_attachments(key)
headers[:attachment_specs] = attachment_specs if attachment_specs.present?
```

#### Modified: `send_mail`

Extract and process attachments:

```ruby
def send_mail(headers, fallback = nil)
  attachment_specs = headers.delete(:attachment_specs)
  begin
    mail_obj = mail headers
    process_attachments(mail_obj, attachment_specs)
    mail_obj
  rescue ActionView::MissingTemplate => e
    if fallback.present?
      mail_obj = mail headers.merge(template_name: fallback)
      process_attachments(mail_obj, attachment_specs)
      mail_obj
    else
      raise e
    end
  end
end
```

### Generator Template

Add commented configuration example to `activity_notification.rb` template.

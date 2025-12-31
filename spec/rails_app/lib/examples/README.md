# Activity Notification Examples

This directory contains working implementation examples for features documented in the Activity Notification gem.

## Email Attachments

The email attachments feature demonstrates how to add file attachments to notification emails using a custom mailer class.

### Files

- **`email_attachments_examples.rb`** - Complete usage examples and code snippets
- **`../app/mailers/custom_notification_mailer.rb`** - Custom mailer implementation with attachment support
- **`../app/models/invoice.rb`** - Example notifiable model that generates PDF attachments
- **`../app/services/monthly_report_generator.rb`** - Service for generating monthly report attachments
- **`../app/views/activity_notification/mailer/users/invoice/created.html.erb`** - Email template for invoice notifications
- **`../app/views/activity_notification/mailer/users/report/monthly.html.erb`** - Email template for monthly reports with inline images

### Quick Start

1. **Configure the custom mailer** in your initializer (`config/initializers/activity_notification.rb`):

```ruby
ActivityNotification.configure do |config|
  config.mailer = 'CustomNotificationMailer'
  config.email_enabled = true
  config.mailer_sender = 'notifications@example.com'
end
```

2. **Run migrations** to create the invoices table:

```bash
rails db:migrate
```

3. **Try an example** in your Rails console:

```ruby
# Create an invoice with email notification
user = User.first
invoice = Invoice.create!(
  user: user,
  amount: 250.00,
  status: 'pending',
  description: 'Monthly subscription fee'
)

# Send notification with PDF attachment
invoice.notify :users, key: 'invoice.created'
```

### Features Demonstrated

1. **Filesystem attachments** - Attach files from your local filesystem
2. **Generated content attachments** - Generate PDFs or other content on-the-fly
3. **Inline image attachments** - Embed images in email templates
4. **Batch notification attachments** - Add summary reports to batch emails
5. **Remote file attachments** - Download and attach files from URLs
6. **Conditional attachments** - Different attachments based on notification keys
7. **Error handling** - Graceful fallback when attachments fail

### Attachment Types Supported

- **PDF documents** - Invoices, reports, summaries
- **CSV data files** - Exportable data and statistics
- **Images** - Logos, charts, inline images
- **Any file format** - Using ActionMailer's `attachments` API

### Customization

The `CustomNotificationMailer` can be extended or modified to support your specific attachment needs:

```ruby
class CustomNotificationMailer < ActivityNotification::Mailer
  private

  def add_attachments(notification)
    # Add your custom attachment logic here
    case notification.key
    when 'my.custom.notification'
      attachments['custom.pdf'] = generate_custom_pdf(notification)
    end
  end
end
```

### Testing

Test email attachments in development using the `letter_opener` gem:

```ruby
# Gemfile
gem 'letter_opener', group: :development

# config/environments/development.rb
config.action_mailer.delivery_method = :letter_opener
config.action_mailer.perform_deliveries = true
```

### Documentation

For complete documentation, see:
- [docs/Functions.md](../../../docs/Functions.md#adding-email-attachments) - Full documentation
- `email_attachments_examples.rb` - Usage examples and code snippets

### Support

For issues or questions:
- GitHub Issues: https://github.com/simukappu/activity_notification/issues
- Documentation: http://www.rubydoc.info/github/simukappu/activity_notification/

## Future Examples

This directory will be expanded with more working implementations of documented features. Contributions welcome!

# Email Attachments Implementation

This directory contains the complete working implementation of the email attachments feature documented in `docs/Functions.md`.

## Overview

The email attachments feature allows you to add file attachments to notification emails by extending the `ActivityNotification::Mailer` class. This implementation demonstrates various types of attachments including:

- PDF documents (invoices, reports)
- CSV data files
- Images (logos, inline images)
- Remote files
- Batch notification summaries

## Implementation Status

✅ **Complete** - All documented examples have been implemented as working code.

## Files Created

### Core Implementation

1. **`spec/rails_app/app/mailers/custom_notification_mailer.rb`**
   - Fully functional custom mailer with attachment support
   - Implements all examples from documentation
   - Includes error handling and graceful fallbacks

2. **`spec/rails_app/app/models/invoice.rb`**
   - Example notifiable model with PDF generation
   - Demonstrates `acts_as_notifiable` with email support
   - Includes `generate_pdf` method for creating invoice PDFs

3. **`spec/rails_app/app/services/monthly_report_generator.rb`**
   - Service class for generating monthly activity reports
   - Produces both PDF and CSV formats
   - Includes notification statistics and breakdowns

### Email Templates

4. **`spec/rails_app/app/views/activity_notification/mailer/users/report/monthly.html.erb`**
   - HTML email template for monthly reports
   - Demonstrates inline image attachment usage
   - Responsive design with professional styling

5. **`spec/rails_app/app/views/activity_notification/mailer/users/report/monthly.text.erb`**
   - Plain text version of monthly report email

6. **`spec/rails_app/app/views/activity_notification/mailer/users/invoice/created.html.erb`**
   - HTML email template for invoice notifications
   - Shows invoice details and references PDF attachment

7. **`spec/rails_app/app/views/activity_notification/mailer/users/invoice/created.text.erb`**
   - Plain text version of invoice email

### Database

8. **`spec/rails_app/db/migrate/20250101000000_create_invoices.rb`**
   - Migration for creating the invoices table
   - Includes indexes for performance

### Documentation & Examples

9. **`spec/rails_app/lib/examples/email_attachments_examples.rb`**
   - Complete usage examples for all attachment types
   - Ready-to-run code snippets
   - Testing and debugging examples

10. **`spec/rails_app/lib/examples/README.md`**
    - Quick start guide
    - Feature documentation
    - Configuration instructions

### Tests

11. **`spec/mailers/custom_notification_mailer_spec.rb`**
    - Comprehensive tests for CustomNotificationMailer
    - Tests all attachment types
    - Error handling tests

12. **`spec/models/invoice_spec.rb`**
    - Tests for Invoice model
    - PDF generation tests
    - Notification integration tests

13. **`spec/factories/invoices.rb`**
    - Factory for Invoice model

14. **`spec/services/monthly_report_generator_spec.rb`**
    - Tests for MonthlyReportGenerator
    - PDF and CSV generation tests

15. **`spec/integration/email_attachments_integration_spec.rb`**
    - End-to-end integration tests
    - Complete workflow tests
    - Multiple scenario tests

## Quick Start

### 1. Configure the Custom Mailer

Edit `config/initializers/activity_notification.rb`:

```ruby
ActivityNotification.configure do |config|
  config.mailer = 'CustomNotificationMailer'
  config.email_enabled = true
  config.mailer_sender = 'notifications@example.com'
end
```

### 2. Run Migrations

```bash
cd spec/rails_app
rails db:migrate
```

### 3. Try It Out

```ruby
# In Rails console
user = User.first

# Create an invoice with email notification
invoice = Invoice.create!(
  user: user,
  amount: 250.00,
  status: 'pending',
  description: 'Monthly subscription fee'
)

# Send notification with PDF attachment
invoice.notify :users, key: 'invoice.created'
```

## Features Implemented

### 1. Invoice PDF Attachments
- ✅ Automatic PDF generation from Invoice model
- ✅ Email template with invoice details
- ✅ Attachment naming convention

### 2. Monthly Report Attachments
- ✅ PDF report with activity statistics
- ✅ CSV data export
- ✅ User-specific report generation
- ✅ Professional email templates

### 3. Filesystem Attachments
- ✅ Attach files from local filesystem
- ✅ Path validation and existence checks
- ✅ Automatic filename detection

### 4. Inline Image Attachments
- ✅ Embed images in email templates
- ✅ Logo and branding support
- ✅ Proper HTML integration

### 5. Batch Notification Summaries
- ✅ Summary PDF for multiple notifications
- ✅ Custom batch email templates
- ✅ Notification listing and statistics

### 6. Remote File Attachments
- ✅ Download and attach files from URLs
- ✅ Error handling and graceful fallbacks
- ✅ Logging for debugging

### 7. Conditional Attachments
- ✅ Different attachments based on notification key
- ✅ Flexible attachment logic
- ✅ Easy to extend

### 8. Error Handling
- ✅ Graceful fallback when attachments fail
- ✅ Comprehensive error logging
- ✅ Email still sent without failed attachments

## Testing

Run the tests to verify everything works:

```bash
cd spec/rails_app
bundle exec rspec spec/mailers/custom_notification_mailer_spec.rb
bundle exec rspec spec/models/invoice_spec.rb
bundle exec rspec spec/services/monthly_report_generator_spec.rb
bundle exec rspec spec/integration/email_attachments_integration_spec.rb
```

## Development Notes

### For Production Use

The current implementation uses simple text-based PDF generation for demonstration. For production, you should integrate a proper PDF library:

**Recommended PDF libraries:**
- [Prawn](https://github.com/prawnpdf/prawn) - Pure Ruby PDF generation
- [WickedPDF](https://github.com/mileszs/wicked_pdf) - HTML to PDF using wkhtmltopdf
- [CombinePDF](https://github.com/boazsegev/combine_pdf) - PDF manipulation

**Example with Prawn:**

```ruby
def generate_pdf
  require 'prawn'
  
  Prawn::Document.new do |pdf|
    pdf.text "Invoice ##{id}", size: 24, style: :bold
    pdf.move_down 20
    pdf.text "Amount: $#{amount}"
    # Add more content...
  end.render
end
```

### Extending the Implementation

To add new attachment types:

1. Add a new condition in `CustomNotificationMailer#add_attachments`
2. Create the attachment generation method
3. Add corresponding email templates
4. Write tests

Example:

```ruby
def add_attachments(notification)
  # ... existing code ...
  
  if notification.key == 'statement.monthly'
    attach_account_statement(notification)
  end
end

def attach_account_statement(notification)
  # Your implementation here
end
```

## Architecture

```
CustomNotificationMailer (extends ActivityNotification::Mailer)
├── send_notification_email
│   ├── add_attachments
│   │   ├── Filesystem attachments
│   │   ├── PDF generation
│   │   ├── Inline images
│   │   └── Remote files
│   └── super (calls parent method)
└── send_batch_notification_email
    ├── add_batch_attachments
    │   └── Summary PDF generation
    └── super (calls parent method)
```

## Performance Considerations

- **PDF Generation**: Consider caching generated PDFs for large documents
- **Remote Files**: Implement timeout handling for remote downloads
- **Large Attachments**: Monitor email size limits (typically 10-25 MB)
- **Background Jobs**: Use ActiveJob for async email delivery with attachments

## Security Considerations

- ✅ Path validation for filesystem attachments
- ✅ Error handling for remote file downloads
- ✅ No hardcoded sensitive data
- ⚠️ Consider access control for attachment content
- ⚠️ Validate file types before attaching
- ⚠️ Implement size limits for attachments

## Support

For questions or issues:
- See documentation: `docs/Functions.md`
- Check examples: `lib/examples/email_attachments_examples.rb`
- Run tests for reference implementations
- GitHub Issues: https://github.com/simukappu/activity_notification/issues

## License

This implementation follows the same MIT License as the activity_notification gem.

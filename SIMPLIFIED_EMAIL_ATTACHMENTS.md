# Email Attachments - Minimal Implementation

## Overview

This is a **minimal, focused implementation** that converts the email attachments documentation examples into working code. This simplified version addresses the core requirement without over-engineering.

## What's Included

This minimal implementation includes only the essentials:

### 1. Core Implementation (3 files)
- **CustomNotificationMailer** - Adds PDF attachments to invoice notifications
- **Invoice Model** - Simple notifiable model with PDF generation
- **Migration** - Database table for invoices

### 2. Email Templates (2 files)
- HTML and text templates for invoice notifications

### 3. Tests (2 files)
- Invoice model tests (validations, notifications, PDF generation)
- Mailer tests (attachment functionality)

### 4. Factory (1 file)
- FactoryBot definition for Invoice model

**Total: 8 files** (down from 27+ files in the complex version)

## What Was Removed

To keep this PR manageable, the following were removed and can be added in separate PRs:

- ❌ Monthly report generator service (separate feature)
- ❌ Monthly report templates (separate feature)
- ❌ Advanced test files (helpers, views, factory-specific, advanced scenarios)
- ❌ Integration test suite (can be added later)
- ❌ Examples directory with 10+ examples (separate documentation PR)
- ❌ Multiple documentation markdown files
- ❌ Test runner scripts
- ❌ Complex attachment types (remote files, inline images, batch summaries)

## How to Use

### 1. Run the migration
```bash
cd spec/rails_app
bundle exec rake db:migrate RAILS_ENV=test
```

### 2. Basic usage
```ruby
# Create an invoice
user = User.first
invoice = Invoice.create!(
  user: user,
  amount: 100.00,
  description: 'Subscription fee'
)

# Send notification with PDF attachment
invoice.notify :users, key: 'invoice.created'
```

### 3. Run tests
```bash
bundle exec rspec spec/models/invoice_spec.rb
bundle exec rspec spec/mailers/custom_notification_mailer_spec.rb
```

## Architecture

```
Invoice (notifiable)
  └── creates notification → ActivityNotification::Notification
      └── triggers → CustomNotificationMailer
          └── adds attachment → invoice.generate_pdf
          └── sends email with PDF
```

## Extension Points

To add more attachment types later:

1. Add new case in `CustomNotificationMailer#add_attachments`
2. Create the corresponding model/service
3. Add email templates for the new notification key
4. Add tests

## Benefits of This Simplified Approach

1. **Easier to Review** - 8 files vs 27+ files
2. **Clear Purpose** - One concrete example that works
3. **Easy to Test** - Minimal test coverage for core functionality
4. **Room to Grow** - Clear patterns for adding more features
5. **Matches Documentation** - Implements the examples from docs/Functions.md

## Future Enhancements (Separate PRs)

These can be added incrementally in follow-up PRs:

1. **PR #2**: Add monthly report generator with attachments
2. **PR #3**: Add batch notification summaries
3. **PR #4**: Add integration test suite
4. **PR #5**: Add comprehensive examples directory
5. **PR #6**: Add advanced features (remote files, inline images)

## Files Changed

```
spec/rails_app/app/mailers/custom_notification_mailer.rb (modified)
spec/rails_app/app/models/invoice.rb (new)
spec/rails_app/db/migrate/20250101000000_create_invoices.rb (new)
spec/rails_app/app/views/activity_notification/mailer/users/invoice/created.html.erb (new)
spec/rails_app/app/views/activity_notification/mailer/users/invoice/created.text.erb (new)
spec/factories/invoices.rb (new)
spec/models/invoice_spec.rb (new)
spec/mailers/custom_notification_mailer_spec.rb (new)
```

## Testing Philosophy

- Tests cover the essential functionality
- Model tests verify: validations, associations, PDF generation, notifications
- Mailer tests verify: attachments are added, content is correct
- No over-testing of edge cases in this minimal version

## Notes

- This is a Rails engine test app implementation (in spec/rails_app)
- The Invoice model uses acts_as_notifiable from ActivityNotification
- PDF generation is intentionally simple (plain text) - can be enhanced with Prawn/WickedPDF later
- Error handling is minimal but sufficient for the example

---

**Simplified by**: Breaking down complex PR #194 into manageable pieces  
**Core requirement**: Convert documentation examples to working code ✅  
**Status**: Ready for review and testing

# Email Attachments Example
# This file demonstrates how to use the CustomNotificationMailer with email attachments
# as documented in docs/Functions.md

# Example 1: Using the Invoice model with PDF attachments
# ========================================================

# First, ensure your initializer is configured to use the CustomNotificationMailer
# In config/initializers/activity_notification.rb:
#
# ActivityNotification.configure do |config|
#   config.mailer = 'CustomNotificationMailer'
#   config.email_enabled = true
#   config.mailer_sender = 'notifications@example.com'
# end

# Create an invoice for a user
def create_invoice_with_email_notification
  user = User.first # or User.find(user_id)
  
  invoice = Invoice.create!(
    user: user,
    amount: 250.00,
    status: 'pending',
    description: 'Monthly subscription fee'
  )
  
  # Send notification with PDF attachment
  # The CustomNotificationMailer will automatically attach the invoice PDF
  invoice.notify :users, key: 'invoice.created'
  
  puts "Invoice created and notification sent with PDF attachment"
end

# Example 2: Sending monthly reports with attachments
# ===================================================

def send_monthly_report_to_user
  user = User.first # or User.find(user_id)
  
  # Create a notification that will trigger the monthly report attachment
  # You can use any notifiable object, or create a dedicated Report model
  article = Article.first # Using an existing model as the notifiable
  
  notification = ActivityNotification::Notification.create!(
    target: user,
    notifiable: article,
    key: 'report.monthly',
    group: article
  )
  
  # Send the email with attachments
  # The CustomNotificationMailer will attach monthly_report.pdf and monthly_data.csv
  ActivityNotification::Mailer.send_notification_email(notification).deliver_now
  
  puts "Monthly report sent with PDF and CSV attachments"
end

# Example 3: Attaching files from the filesystem
# ==============================================

# Add an attachment_path method to your notifiable model
class Comment
  # ... existing code ...
  
  def attachment_path
    # Return path to an attachment file if it exists
    return nil unless respond_to?(:has_attachment?) && has_attachment?
    Rails.root.join('public', 'uploads', 'comments', id.to_s, 'attachment.pdf').to_s
  end
end

def send_comment_with_file_attachment
  user = User.first
  article = Article.first
  comment = article.comments.create!(
    user: user,
    body: 'Check out the attached document'
  )
  
  # The CustomNotificationMailer will automatically attach the file at attachment_path
  comment.notify :users, key: 'comment.reply'
  
  puts "Comment notification sent with file attachment"
end

# Example 4: Using inline image attachments
# =========================================

# Add a logo_path method to your notifiable model
class Report
  def logo_path
    Rails.root.join('app', 'assets', 'images', 'logo.png').to_s
  end
end

def send_report_with_inline_logo
  user = User.first
  report = Report.create!(user: user)
  
  # The CustomNotificationMailer will attach the logo inline
  # Reference it in your email template with: <%= image_tag attachments['logo.png'].url %>
  report.notify :users, key: 'report.completed'
  
  puts "Report notification sent with inline logo image"
end

# Example 5: Batch notifications with summary attachments
# =======================================================

def send_batch_notification_with_summary
  user = User.first
  
  # Get unopened notifications
  notifications = user.notifications.unopened_only.limit(10)
  
  # Send batch notification
  # The CustomNotificationMailer will attach a summary PDF
  ActivityNotification::Mailer.send_batch_notification_email(
    user,
    notifications,
    'batch.daily_summary'
  ).deliver_now
  
  puts "Batch notification sent with summary PDF attachment"
end

# Example 6: Attaching remote files
# =================================

# Add file_url and filename methods to your notifiable model
class SharedDocument
  acts_as_notifiable :users,
    targets: ->(doc, key) { doc.shared_with_users },
    notifiable_path: :document_path
  
  def file_url
    "https://example.com/documents/#{id}/download"
  end
  
  def filename
    "shared_document_#{id}.pdf"
  end
  
  def document_path
    "/documents/#{id}"
  end
end

def share_document_with_email_attachment
  document = SharedDocument.first
  
  # The CustomNotificationMailer will download and attach the remote file
  document.notify :users, key: 'document.shared'
  
  puts "Document shared with email attachment"
end

# Example 7: Custom attachment logic with different notification keys
# ===================================================================

# You can customize attachment behavior based on notification keys
# See CustomNotificationMailer#add_attachments for examples

def send_notification_with_conditional_attachments
  user = User.first
  article = Article.first
  
  # Different keys trigger different attachment behaviors
  
  # This will attach a report PDF
  article.notify :users, key: 'report.completed'
  
  # This will attach monthly reports (PDF + CSV)
  article.notify :users, key: 'report.monthly'
  
  # This will attach a shared document from remote URL
  article.notify :users, key: 'document.shared'
  
  puts "Multiple notifications sent with different attachment types"
end

# Example 8: Testing email attachments in development
# ==================================================

def test_email_attachments_locally
  # In development, you can test email attachments using letter_opener gem
  # Add to Gemfile: gem 'letter_opener', group: :development
  
  # In config/environments/development.rb:
  # config.action_mailer.delivery_method = :letter_opener
  # config.action_mailer.perform_deliveries = true
  
  user = User.first
  invoice = Invoice.create!(user: user, amount: 150.00)
  
  # Send notification
  invoice.notify :users, key: 'invoice.created'
  
  # The email with attachments will open in your browser
  puts "Check your browser for the email with attachments"
end

# Example 9: Error handling for attachments
# =========================================

# The CustomNotificationMailer includes error handling
# If an attachment fails (e.g., remote file unavailable), 
# the email will still be sent without that attachment

def send_notification_with_graceful_error_handling
  user = User.first
  
  # Even if the remote document fails to download,
  # the email notification will still be delivered
  document = SharedDocument.create!(user: user, file_url: 'https://invalid-url.com/file.pdf')
  document.notify :users, key: 'document.shared'
  
  # Check logs for any attachment errors:
  # Rails.logger.error messages will indicate attachment failures
  
  puts "Notification sent (with graceful attachment error handling)"
end

# Example 10: Using attachments with custom mailer configuration
# =============================================================

# You can configure different mailers for different notification types
# In your initializer:
#
# ActivityNotification.configure do |config|
#   config.mailer = lambda do |notification|
#     case notification.key
#     when /^invoice\./
#       'InvoiceNotificationMailer'  # Custom mailer for invoices
#     when /^report\./
#       'ReportNotificationMailer'   # Custom mailer for reports
#     else
#       'CustomNotificationMailer'   # Default mailer
#     end
#   end
# end

puts "\n" + "=" * 70
puts "Email Attachments Examples"
puts "=" * 70
puts "\nAll examples are ready to use!"
puts "See this file for implementation details and usage examples."
puts "\nTo use these examples:"
puts "1. Configure CustomNotificationMailer in your initializer"
puts "2. Run migrations to create the invoices table"
puts "3. Use the example methods above in your Rails console or application"
puts "\nFor more information, see docs/Functions.md"
puts "=" * 70

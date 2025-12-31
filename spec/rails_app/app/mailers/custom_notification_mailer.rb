# Custom mailer with email attachment support
# This mailer demonstrates how to add attachments to notification emails
class CustomNotificationMailer < ActivityNotification::Mailer
  def send_notification_email(notification, options = {})
    # Add attachments before sending the email
    add_attachments(notification)
    
    # Call the parent method to send the email
    super
  end

  def send_batch_notification_email(target, notifications, batch_key, options = {})
    # Add attachments for batch emails
    add_batch_attachments(target, notifications)
    
    # Call the parent method to send the email
    super
  end

  private

  def add_attachments(notification)
    # Add attachments using ActionMailer's attachments API
    # Example 1: Attach a file from the filesystem
    if notification.notifiable.respond_to?(:attachment_path) && 
       notification.notifiable.attachment_path.present? &&
       File.exist?(notification.notifiable.attachment_path)
      attachments[File.basename(notification.notifiable.attachment_path)] = 
        File.read(notification.notifiable.attachment_path)
    end

    # Example 2: Attach generated content (e.g., PDF)
    if notification.key == 'report.completed'
      attachments['report.pdf'] = {
        mime_type: 'application/pdf',
        content: generate_report_pdf(notification)
      }
    end

    # Example 3: Attach image inline for embedding in email
    if notification.notifiable.respond_to?(:logo_path) && 
       notification.notifiable.logo_path.present? &&
       File.exist?(notification.notifiable.logo_path)
      attachments.inline['logo.png'] = File.read(notification.notifiable.logo_path)
    end

    # Example 4: Attach invoice PDF
    if notification.key == 'invoice.created' && notification.notifiable.respond_to?(:generate_pdf)
      invoice = notification.notifiable
      attachments["invoice_#{invoice.id}.pdf"] = {
        mime_type: 'application/pdf',
        content: invoice.generate_pdf
      }
    end

    # Example 5: Attach monthly report
    if notification.key == 'report.monthly'
      attach_monthly_report(notification)
    end

    # Example 6: Attach shared document
    if notification.key == 'document.shared'
      attach_shared_document(notification)
    end
  end

  def add_batch_attachments(target, notifications)
    # Example: Attach a summary report for batch notifications
    attachments['notification_summary.pdf'] = {
      mime_type: 'application/pdf',
      content: generate_batch_summary_pdf(target, notifications)
    }
  end

  def generate_report_pdf(notification)
    # Simple PDF generation for demonstration
    # In production, you would use a library like Prawn or WickedPDF
    "PDF Report for notification #{notification.id}\n" \
    "Notifiable: #{notification.notifiable_type} ##{notification.notifiable_id}\n" \
    "Target: #{notification.target_type} ##{notification.target_id}\n" \
    "Created: #{notification.created_at}"
  end

  def generate_batch_summary_pdf(target, notifications)
    # Simple batch PDF generation for demonstration
    content = "Batch Notification Summary\n"
    content += "Target: #{target.class.name} ##{target.id}\n"
    content += "Total notifications: #{notifications.count}\n\n"
    
    notifications.each_with_index do |notification, index|
      content += "#{index + 1}. #{notification.key} - #{notification.notifiable_type} ##{notification.notifiable_id}\n"
    end
    
    content
  end

  def attach_monthly_report(notification)
    target = notification.target
    
    # Generate a simple monthly report
    report_content = "Monthly Report\n"
    report_content += "User: #{target.class.name} ##{target.id}\n"
    report_content += "Month: #{Date.current.last_month.strftime('%B %Y')}\n"
    report_content += "Generated: #{Time.current}\n"
    
    attachments['monthly_report.pdf'] = {
      mime_type: 'application/pdf',
      content: report_content
    }
    
    # Optionally attach CSV data as well
    csv_content = "Date,Activity,Count\n"
    csv_content += "#{Date.current.last_month},Notifications,#{target.notifications.count}\n"
    
    attachments['monthly_data.csv'] = {
      mime_type: 'text/csv',
      content: csv_content
    }
  end

  def attach_shared_document(notification)
    document = notification.notifiable
    
    # Handle remote file downloads with error handling
    if document.respond_to?(:file_url) && document.file_url.present?
      begin
        require 'open-uri'
        filename = document.respond_to?(:filename) ? document.filename : 'document.pdf'
        attachments[filename] = URI.open(document.file_url).read
      rescue StandardError => e
        # Handle errors gracefully - email will still be sent without attachment
        Rails.logger.error("Failed to attach document: #{e.message}")
      end
    end
  end
end
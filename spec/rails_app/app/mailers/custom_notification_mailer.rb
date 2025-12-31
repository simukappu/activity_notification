class CustomNotificationMailer < ActivityNotification::Mailer
  # Override to add attachments before sending notification emails
  def send_notification_email(notification, options = {})
    add_attachments(notification)
    super
  end

  private

  def add_attachments(notification)
    # Example: Attach invoice PDF when notifying about invoice creation
    if notification.key == 'invoice.created' && notification.notifiable.is_a?(Invoice)
      invoice = notification.notifiable
      attachments["invoice_#{invoice.id}.pdf"] = {
        mime_type: 'application/pdf',
        content: invoice.generate_pdf
      }
    end
  end
end
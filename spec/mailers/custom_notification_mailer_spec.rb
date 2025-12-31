require 'rails_helper'

RSpec.describe CustomNotificationMailer, type: :mailer do
  let(:user) { create(:user) }
  let(:invoice) { create(:invoice, user: user, amount: 250.00, description: 'Subscription fee') }
  let(:notification) { invoice.notify(:users, key: 'invoice.created').first }

  describe '#send_notification_email' do
    let(:mail) { CustomNotificationMailer.send_notification_email(notification) }

    it 'sends email to the correct recipient' do
      expect(mail.to).to eq([user.email])
    end

    it 'includes invoice PDF attachment' do
      expect(mail.attachments.size).to eq(1)
      
      attachment = mail.attachments.first
      expect(attachment.filename).to eq("invoice_#{invoice.id}.pdf")
      expect(attachment.content_type).to start_with('application/pdf')
    end

    it 'attachment contains invoice details' do
      attachment = mail.attachments.first
      content = attachment.body.decoded
      
      expect(content).to include("Invoice ##{invoice.id}")
      expect(content).to include("Amount: $250.0")
      expect(content).to include("Description: Subscription fee")
    end

    it 'renders the email body correctly' do
      expect(mail.body.encoded).to include('Invoice Created')
      expect(mail.body.encoded).to include("Invoice ID: ##{invoice.id}")
      expect(mail.body.encoded).to include("Amount: $#{invoice.amount}")
    end
  end

  describe 'with different notification keys' do
    let(:comment_notification) do
      comment = create(:comment)
      comment.notify(:users, key: 'comment.created').first
    end

    it 'does not add attachments for non-invoice notifications' do
      mail = CustomNotificationMailer.send_notification_email(comment_notification)
      expect(mail.attachments.size).to eq(0)
    end
  end
end

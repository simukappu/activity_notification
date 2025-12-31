require 'rails_helper'

describe 'Email Attachments Integration', type: :integration do
  let(:user) { create(:user) }
  
  before do
    ActivityNotification.config.mailer = 'CustomNotificationMailer'
    ActivityNotification.config.email_enabled = true
  end
  
  describe 'Invoice notification workflow' do
    it 'creates invoice, sends notification with PDF attachment' do
      # Create invoice
      invoice = Invoice.create!(
        user: user,
        amount: 250.00,
        status: 'pending',
        description: 'Monthly subscription'
      )
      
      # Send notification
      expect {
        invoice.notify :users, key: 'invoice.created'
      }.to change { user.notifications.count }.by(1)
      
      # Verify notification
      notification = user.notifications.last
      expect(notification.notifiable).to eq(invoice)
      expect(notification.key).to eq('invoice.created')
      
      # Verify email would have attachment
      mail = CustomNotificationMailer.send_notification_email(notification)
      
      expect(mail.attachments.size).to eq(1)
      expect(mail.attachments.first.filename).to eq("invoice_#{invoice.id}.pdf")
      
      # Verify PDF content
      pdf_content = mail.attachments.first.body.decoded
      expect(pdf_content).to include("INVOICE ##{invoice.id}")
      expect(pdf_content).to include("Amount: $250.0")
    end
  end
  
  describe 'Monthly report workflow' do
    let!(:notifications) do
      create_list(:notification, 10, target: user)
    end
    
    before do
      # Mark some as opened
      notifications.take(6).each { |n| n.open! }
    end
    
    it 'generates and sends monthly report with multiple attachments' do
      article = create(:article, user: user)
      
      # Create notification for monthly report
      notification = ActivityNotification::Notification.create!(
        target: user,
        notifiable: article,
        key: 'report.monthly'
      )
      
      # Send email with attachments
      mail = CustomNotificationMailer.send_notification_email(notification)
      
      # Verify both PDF and CSV attachments
      expect(mail.attachments.size).to eq(2)
      
      pdf_attachment = mail.attachments.find { |a| a.filename == 'monthly_report.pdf' }
      csv_attachment = mail.attachments.find { |a| a.filename == 'monthly_data.csv' }
      
      expect(pdf_attachment).to be_present
      expect(csv_attachment).to be_present
      
      # Verify PDF content
      pdf_content = pdf_attachment.body.decoded
      expect(pdf_content).to include('MONTHLY ACTIVITY REPORT')
      expect(pdf_content).to include(user.name)
      expect(pdf_content).to include("Total Notifications: #{user.notifications.count}")
      expect(pdf_content).to include("Opened: 6")
      expect(pdf_content).to include("Unopened: 4")
      
      # Verify CSV content
      csv_content = csv_attachment.body.decoded
      expect(csv_content).to include('Month,Total Notifications,Opened,Unopened')
      expect(csv_content).to include('Notification Type,Count')
    end
  end
  
  describe 'Batch notification with summary' do
    let!(:notifications) do
      create_list(:notification, 5, target: user)
    end
    
    it 'sends batch email with summary PDF attachment' do
      mail = CustomNotificationMailer.send_batch_notification_email(
        user,
        notifications,
        'batch.daily_summary'
      )
      
      expect(mail.attachments.size).to eq(1)
      expect(mail.attachments.first.filename).to eq('notification_summary.pdf')
      
      # Verify summary content
      summary_content = mail.attachments.first.body.decoded
      expect(summary_content).to include('Batch Notification Summary')
      expect(summary_content).to include("Target: #{user.class.name} ##{user.id}")
      expect(summary_content).to include("Total notifications: #{notifications.count}")
      
      # Verify each notification is listed
      notifications.each_with_index do |notification, index|
        expect(summary_content).to include("#{index + 1}.")
        expect(summary_content).to include(notification.key)
      end
    end
  end
  
  describe 'File system attachment workflow' do
    let(:article) { create(:article, user: user) }
    let(:comment) { create(:comment, article: article, user: user) }
    let(:attachment_path) { Rails.root.join('tmp', 'test_attachment.pdf') }
    
    before do
      FileUtils.mkdir_p(File.dirname(attachment_path))
      File.write(attachment_path, 'Test PDF content for comment attachment')
      allow_any_instance_of(Comment).to receive(:attachment_path).and_return(attachment_path.to_s)
    end
    
    after do
      File.delete(attachment_path) if File.exist?(attachment_path)
    end
    
    it 'attaches file from filesystem to notification email' do
      # Create notification
      notification = ActivityNotification::Notification.create!(
        target: user,
        notifiable: comment,
        key: 'comment.reply'
      )
      
      # Send email
      mail = CustomNotificationMailer.send_notification_email(notification)
      
      # Verify attachment
      expect(mail.attachments.size).to eq(1)
      expect(mail.attachments.first.filename).to eq('test_attachment.pdf')
      expect(mail.attachments.first.body.decoded).to eq('Test PDF content for comment attachment')
    end
  end
  
  describe 'Error handling workflow' do
    it 'gracefully handles missing attachment files' do
      article = create(:article, user: user)
      comment = create(:comment, article: article, user: user)
      
      # Set invalid attachment path
      allow_any_instance_of(Comment).to receive(:attachment_path)
        .and_return('/non/existent/file.pdf')
      
      notification = ActivityNotification::Notification.create!(
        target: user,
        notifiable: comment,
        key: 'comment.reply'
      )
      
      # Email should still be sent without attachment
      expect {
        mail = CustomNotificationMailer.send_notification_email(notification)
        expect(mail.attachments.size).to eq(0)
      }.not_to raise_error
    end
    
    it 'handles remote file download failures gracefully' do
      article = create(:article, user: user)
      
      # Simulate remote document
      allow(article).to receive(:file_url).and_return('https://invalid-url.com/file.pdf')
      allow(article).to receive(:filename).and_return('document.pdf')
      
      notification = ActivityNotification::Notification.create!(
        target: user,
        notifiable: article,
        key: 'document.shared'
      )
      
      # Should log error but still send email
      expect(Rails.logger).to receive(:error).with(/Failed to attach document/)
      
      expect {
        mail = CustomNotificationMailer.send_notification_email(notification)
        expect(mail.attachments.size).to eq(0)
      }.not_to raise_error
    end
  end
  
  describe 'Multiple attachment types workflow' do
    it 'handles different notification keys with appropriate attachments' do
      article = create(:article, user: user)
      
      # Test report.completed
      notification1 = ActivityNotification::Notification.create!(
        target: user,
        notifiable: article,
        key: 'report.completed'
      )
      mail1 = CustomNotificationMailer.send_notification_email(notification1)
      expect(mail1.attachments.size).to eq(1)
      expect(mail1.attachments.first.filename).to eq('report.pdf')
      
      # Test invoice.created
      invoice = Invoice.create!(user: user, amount: 100.00)
      notification2 = ActivityNotification::Notification.create!(
        target: user,
        notifiable: invoice,
        key: 'invoice.created'
      )
      mail2 = CustomNotificationMailer.send_notification_email(notification2)
      expect(mail2.attachments.size).to eq(1)
      expect(mail2.attachments.first.filename).to eq("invoice_#{invoice.id}.pdf")
      
      # Test report.monthly
      notification3 = ActivityNotification::Notification.create!(
        target: user,
        notifiable: article,
        key: 'report.monthly'
      )
      mail3 = CustomNotificationMailer.send_notification_email(notification3)
      expect(mail3.attachments.size).to eq(2) # PDF and CSV
    end
  end
end

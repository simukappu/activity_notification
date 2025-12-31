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
  
  describe 'Complete end-to-end workflows' do
    context 'invoice creation and notification workflow' do
      it 'creates invoice, notification, and sends email with PDF' do
        # Step 1: Create invoice
        invoice = Invoice.create!(
          user: user,
          amount: 350.00,
          status: 'pending',
          description: 'Consulting services'
        )
        
        expect(invoice).to be_persisted
        expect(invoice.amount).to eq(350.00)
        
        # Step 2: Create notification
        expect {
          invoice.notify :users, key: 'invoice.created'
        }.to change { user.notifications.count }.by(1)
        
        notification = user.notifications.last
        expect(notification.notifiable).to eq(invoice)
        
        # Step 3: Send email with attachment
        mail = CustomNotificationMailer.send_notification_email(notification)
        
        expect(mail.to).to include(user.email)
        expect(mail.attachments.size).to eq(1)
        
        # Verify PDF content
        pdf = mail.attachments.first
        expect(pdf.filename).to eq("invoice_#{invoice.id}.pdf")
        expect(pdf.body.decoded).to include("INVOICE ##{invoice.id}")
        expect(pdf.body.decoded).to include('Consulting services')
      end
    end
    
    context 'monthly report generation workflow' do
      let!(:various_notifications) do
        notifications = []
        notifications += create_list(:notification, 5, target: user, key: 'article.created')
        notifications += create_list(:notification, 3, target: user, key: 'comment.posted')
        notifications += create_list(:notification, 2, target: user, key: 'invoice.created')
        notifications
      end
      
      before do
        various_notifications.take(6).each { |n| n.open! }
      end
      
      it 'generates comprehensive monthly report with statistics' do
        article = create(:article, user: user)
        notification = ActivityNotification::Notification.create!(
          target: user,
          notifiable: article,
          key: 'report.monthly'
        )
        
        mail = CustomNotificationMailer.send_notification_email(notification)
        
        # Verify both attachments
        expect(mail.attachments.size).to eq(2)
        pdf = mail.attachments.find { |a| a.filename == 'monthly_report.pdf' }
        csv = mail.attachments.find { |a| a.filename == 'monthly_data.csv' }
        
        # Verify PDF includes all statistics
        pdf_content = pdf.body.decoded
        expect(pdf_content).to include('MONTHLY ACTIVITY REPORT')
        expect(pdf_content).to include("Total Notifications: #{user.notifications.count}")
        expect(pdf_content).to include('Opened: 6')
        expect(pdf_content).to include('Unopened: 4')
        expect(pdf_content).to include('article.created: 5')
        expect(pdf_content).to include('comment.posted: 3')
        expect(pdf_content).to include('invoice.created: 2')
        
        # Verify CSV structure
        csv_content = csv.body.decoded
        expect(csv_content).to include('Month,Total Notifications,Opened,Unopened')
        expect(csv_content).to include('Notification Type,Count')
      end
    end
    
    context 'batch notification workflow with diverse content' do
      let!(:diverse_notifiables) do
        {
          articles: create_list(:article, 2, user: user),
          invoices: [
            Invoice.create!(user: user, amount: 100.00),
            Invoice.create!(user: user, amount: 200.00)
          ]
        }
      end
      
      let!(:notifications) do
        [
          create(:notification, target: user, notifiable: diverse_notifiables[:articles][0], key: 'article.published'),
          create(:notification, target: user, notifiable: diverse_notifiables[:articles][1], key: 'article.updated'),
          create(:notification, target: user, notifiable: diverse_notifiables[:invoices][0], key: 'invoice.created'),
          create(:notification, target: user, notifiable: diverse_notifiables[:invoices][1], key: 'invoice.created'),
        ]
      end
      
      it 'creates batch summary with all notification types' do
        mail = CustomNotificationMailer.send_batch_notification_email(
          user,
          notifications,
          'batch.daily_summary'
        )
        
        expect(mail.attachments.size).to eq(1)
        summary = mail.attachments.first.body.decoded
        
        # Verify summary includes all notifications
        expect(summary).to include('article.published')
        expect(summary).to include('article.updated')
        expect(summary).to include('invoice.created')
        expect(summary).to include("Total notifications: #{notifications.count}")
      end
    end
    
    context 'error recovery workflow' do
      it 'continues processing even when one attachment fails' do
        article = create(:article, user: user)
        
        # Simulate a scenario where remote file download would fail
        allow(article).to receive(:file_url).and_return('https://invalid-url.example.com/file.pdf')
        allow(article).to receive(:filename).and_return('test.pdf')
        
        notification = ActivityNotification::Notification.create!(
          target: user,
          notifiable: article,
          key: 'document.shared'
        )
        
        # Should not raise error
        expect {
          mail = CustomNotificationMailer.send_notification_email(notification)
          expect(mail).to be_present
          expect(mail.to).to include(user.email)
        }.not_to raise_error
      end
    end
    
    context 'mixed attachment workflow' do
      let(:comment) { create(:comment, article: article, user: user) }
      let(:attachment_path) { Rails.root.join('tmp', 'mixed_test.pdf') }
      let(:logo_path) { Rails.root.join('tmp', 'test_logo.png') }
      
      before do
        FileUtils.mkdir_p(Rails.root.join('tmp'))
        File.write(attachment_path, 'Mixed workflow PDF content')
        File.write(logo_path, 'Mixed workflow logo content')
        allow_any_instance_of(Comment).to receive(:attachment_path).and_return(attachment_path.to_s)
        allow_any_instance_of(Comment).to receive(:logo_path).and_return(logo_path.to_s)
      end
      
      after do
        File.delete(attachment_path) if File.exist?(attachment_path)
        File.delete(logo_path) if File.exist?(logo_path)
      end
      
      it 'handles both regular and inline attachments in one email' do
        notification = ActivityNotification::Notification.create!(
          target: user,
          notifiable: comment,
          key: 'comment.reply'
        )
        
        mail = CustomNotificationMailer.send_notification_email(notification)
        
        # Should have both attachments
        expect(mail.attachments.count).to eq(2)
        
        # Check regular attachment
        regular = mail.attachments.find { |a| !a.inline? && a.filename == 'mixed_test.pdf' }
        expect(regular).to be_present
        expect(regular.body.decoded).to eq('Mixed workflow PDF content')
        
        # Check inline attachment
        inline = mail.attachments.inline.find { |a| a.filename == 'test_logo.png' }
        expect(inline).to be_present
        expect(inline.body.decoded).to eq('Mixed workflow logo content')
      end
    end
    
    context 'performance with multiple recipients' do
      let!(:users) { create_list(:user, 5) }
      let(:article) { create(:article, user: users.first) }
      
      it 'sends notifications to multiple users efficiently' do
        users.each do |recipient|
          notification = ActivityNotification::Notification.create!(
            target: recipient,
            notifiable: article,
            key: 'article.published'
          )
          
          mail = CustomNotificationMailer.send_notification_email(notification)
          expect(mail.to).to include(recipient.email)
        end
      end
    end
    
    context 'idempotency and duplicate prevention' do
      let(:invoice) { Invoice.create!(user: user, amount: 100.00) }
      
      it 'can send same notification multiple times without errors' do
        invoice.notify :users, key: 'invoice.created'
        notification = user.notifications.last
        
        # Send email multiple times
        mail1 = CustomNotificationMailer.send_notification_email(notification)
        mail2 = CustomNotificationMailer.send_notification_email(notification)
        
        expect(mail1.attachments.first.body.decoded).to eq(mail2.attachments.first.body.decoded)
      end
    end
    
    context 'configuration changes during runtime' do
      before do
        ActivityNotification.config.mailer = 'CustomNotificationMailer'
        ActivityNotification.config.email_enabled = true
      end
      
      it 'respects configuration settings' do
        invoice = Invoice.create!(user: user, amount: 150.00)
        notification = ActivityNotification::Notification.create!(
          target: user,
          notifiable: invoice,
          key: 'invoice.created'
        )
        
        mail = CustomNotificationMailer.send_notification_email(notification)
        expect(mail).to be_present
        expect(mail.attachments.size).to eq(1)
      end
    end
  end
  
  describe 'View template integration' do
    context 'monthly report email views' do
      let!(:notifications) { create_list(:notification, 5, target: user) }
      
      before do
        notifications.take(3).each { |n| n.open! }
      end
      
      it 'renders monthly report views with correct data' do
        article = create(:article, user: user)
        notification = ActivityNotification::Notification.create!(
          target: user,
          notifiable: article,
          key: 'report.monthly'
        )
        
        mail = CustomNotificationMailer.send_notification_email(notification)
        
        # Check that email body contains expected content
        expect(mail.body.encoded).to be_present
      end
    end
    
    context 'invoice email views' do
      it 'renders invoice views with correct data' do
        invoice = Invoice.create!(
          user: user,
          amount: 275.00,
          status: 'pending',
          description: 'Monthly subscription'
        )
        
        notification = ActivityNotification::Notification.create!(
          target: user,
          notifiable: invoice,
          key: 'invoice.created'
        )
        
        mail = CustomNotificationMailer.send_notification_email(notification)
        
        expect(mail.body.encoded).to be_present
      end
    end
  end
end

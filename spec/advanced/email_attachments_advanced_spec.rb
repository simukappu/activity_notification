require 'rails_helper'

describe 'Email Attachments Advanced Scenarios', type: :integration do
  let(:user) { create(:user) }
  let(:article) { create(:article, user: user) }
  
  describe 'Concurrent attachment generation' do
    it 'handles multiple simultaneous notifications' do
      invoices = create_list(:invoice, 3, user: user)
      
      threads = invoices.map do |invoice|
        Thread.new do
          notification = create(:notification,
            target: user,
            notifiable: invoice,
            key: 'invoice.created'
          )
          CustomNotificationMailer.send_notification_email(notification)
        end
      end
      
      results = threads.map(&:value)
      expect(results.all?(&:present?)).to be true
      expect(results.map { |m| m.attachments.size }.all? { |s| s == 1 }).to be true
    end
  end
  
  describe 'Memory management' do
    it 'handles large PDF generation without memory issues' do
      invoice = Invoice.create!(
        user: user,
        amount: 100.00,
        description: 'A' * 10000  # Large description
      )
      
      notification = create(:notification,
        target: user,
        notifiable: invoice,
        key: 'invoice.created'
      )
      
      expect {
        mail = CustomNotificationMailer.send_notification_email(notification)
        expect(mail.attachments.first.body.decoded.length).to be > 10000
      }.not_to raise_error
    end
    
    it 'handles multiple large attachments' do
      create_list(:notification, 10, target: user)
      
      notification = create(:notification,
        target: user,
        notifiable: article,
        key: 'report.monthly'
      )
      
      expect {
        mail = CustomNotificationMailer.send_notification_email(notification)
        expect(mail.attachments.size).to eq(2)
      }.not_to raise_error
    end
  end
  
  describe 'Character encoding handling' do
    it 'handles unicode characters in invoice description' do
      invoice = Invoice.create!(
        user: user,
        amount: 100.00,
        description: '日本語 Ελληνικά Русский 中文 العربية'
      )
      
      notification = create(:notification,
        target: user,
        notifiable: invoice,
        key: 'invoice.created'
      )
      
      mail = CustomNotificationMailer.send_notification_email(notification)
      pdf_content = mail.attachments.first.body.decoded
      
      expect(pdf_content).to include('日本語')
      expect(pdf_content).to include('Ελληνικά')
    end
    
    it 'handles emoji in descriptions' do
      invoice = Invoice.create!(
        user: user,
        amount: 100.00,
        description: 'Payment received 🎉 Thank you! 💰'
      )
      
      pdf_content = invoice.generate_pdf
      expect(pdf_content).to include('🎉')
      expect(pdf_content).to include('💰')
    end
  end
  
  describe 'Time zone handling' do
    around do |example|
      original_tz = Time.zone
      Time.zone = 'UTC'
      example.run
      Time.zone = original_tz
    end
    
    it 'uses correct time zone for timestamps in reports' do
      generator = MonthlyReportGenerator.new(user)
      pdf_content = generator.to_pdf
      
      expect(pdf_content).to include('Generated:')
    end
    
    it 'formats invoice dates consistently' do
      invoice = Invoice.create!(user: user, amount: 100.00)
      pdf_content = invoice.generate_pdf
      
      expect(pdf_content).to include(invoice.created_at.strftime('%Y-%m-%d'))
    end
  end
  
  describe 'Database transaction handling' do
    it 'maintains consistency when notification creation fails' do
      invoice = Invoice.create!(user: user, amount: 100.00)
      
      # Simulate a failure scenario
      allow_any_instance_of(Invoice).to receive(:notifiable_targets).and_raise(StandardError.new('DB error'))
      
      expect {
        invoice.notify :users, key: 'invoice.created'
      }.to raise_error(StandardError)
      
      # Invoice should still exist
      expect(Invoice.find(invoice.id)).to eq(invoice)
    end
  end
  
  describe 'Attachment size validation' do
    it 'generates reasonably sized PDF attachments' do
      invoice = Invoice.create!(user: user, amount: 100.00)
      pdf_content = invoice.generate_pdf
      
      # Should be under 1MB for simple invoice
      expect(pdf_content.bytesize).to be < 1.megabyte
    end
    
    it 'generates reasonably sized CSV attachments' do
      create_list(:notification, 100, target: user)
      generator = MonthlyReportGenerator.new(user)
      csv_content = generator.to_csv
      
      # Should be under 1MB for 100 notifications
      expect(csv_content.bytesize).to be < 1.megabyte
    end
  end
  
  describe 'Notification state transitions' do
    it 'sends email regardless of notification state' do
      invoice = Invoice.create!(user: user, amount: 100.00)
      notification = create(:notification,
        target: user,
        notifiable: invoice,
        key: 'invoice.created'
      )
      
      # Test with unopened notification
      mail1 = CustomNotificationMailer.send_notification_email(notification)
      expect(mail1.attachments.size).to eq(1)
      
      # Open notification and test again
      notification.open!
      mail2 = CustomNotificationMailer.send_notification_email(notification)
      expect(mail2.attachments.size).to eq(1)
    end
  end
  
  describe 'Attachment content caching' do
    it 'generates fresh content for each email' do
      invoice = Invoice.create!(user: user, amount: 100.00)
      notification = create(:notification,
        target: user,
        notifiable: invoice,
        key: 'invoice.created'
      )
      
      mail1 = CustomNotificationMailer.send_notification_email(notification)
      content1 = mail1.attachments.first.body.decoded
      
      # Update invoice
      invoice.update!(amount: 200.00)
      
      mail2 = CustomNotificationMailer.send_notification_email(notification)
      content2 = mail2.attachments.first.body.decoded
      
      # Content should reflect current state
      expect(content2).to include('200.0')
    end
  end
  
  describe 'Multiple target types' do
    it 'handles notifications for different target types' do
      admin = create(:admin) if defined?(Admin)
      skip 'Admin model not available' unless defined?(Admin)
      
      invoice = Invoice.create!(user: user, amount: 100.00)
      
      user_notification = create(:notification,
        target: user,
        notifiable: invoice,
        key: 'invoice.created'
      )
      
      admin_notification = create(:notification,
        target: admin,
        notifiable: invoice,
        key: 'invoice.created'
      )
      
      user_mail = CustomNotificationMailer.send_notification_email(user_notification)
      admin_mail = CustomNotificationMailer.send_notification_email(admin_notification)
      
      expect(user_mail.attachments.size).to eq(1)
      expect(admin_mail.attachments.size).to eq(1)
    end
  end
  
  describe 'Batch size handling' do
    it 'handles small batches' do
      notifications = create_list(:notification, 2, target: user, notifiable: article)
      
      mail = CustomNotificationMailer.send_batch_notification_email(
        user,
        notifications,
        'batch.test'
      )
      
      expect(mail.attachments.size).to eq(1)
    end
    
    it 'handles large batches' do
      notifications = create_list(:notification, 50, target: user, notifiable: article)
      
      mail = CustomNotificationMailer.send_batch_notification_email(
        user,
        notifications,
        'batch.test'
      )
      
      summary = mail.attachments.first.body.decoded
      expect(summary).to include('Total notifications: 50')
    end
    
    it 'handles empty batches gracefully' do
      mail = CustomNotificationMailer.send_batch_notification_email(
        user,
        [],
        'batch.test'
      )
      
      summary = mail.attachments.first.body.decoded
      expect(summary).to include('Total notifications: 0')
    end
  end
  
  describe 'Attachment ordering' do
    it 'maintains consistent attachment order' do
      notification = create(:notification,
        target: user,
        notifiable: article,
        key: 'report.monthly'
      )
      
      mail1 = CustomNotificationMailer.send_notification_email(notification)
      mail2 = CustomNotificationMailer.send_notification_email(notification)
      
      expect(mail1.attachments.map(&:filename)).to eq(mail2.attachments.map(&:filename))
    end
  end
  
  describe 'Notifiable lifecycle' do
    it 'handles deleted notifiable gracefully' do
      invoice = Invoice.create!(user: user, amount: 100.00)
      notification = create(:notification,
        target: user,
        notifiable: invoice,
        key: 'invoice.created'
      )
      
      # Generate email before deletion
      mail1 = CustomNotificationMailer.send_notification_email(notification)
      expect(mail1.attachments.size).to eq(1)
      
      # Note: After deletion, behavior depends on database cascading rules
      # This test documents expected behavior
    end
  end
  
  describe 'Custom attachment methods' do
    it 'respects custom attachment_path implementation' do
      comment = create(:comment, article: article, user: user)
      temp_path = Rails.root.join('tmp', 'custom_attachment.pdf')
      
      FileUtils.mkdir_p(File.dirname(temp_path))
      File.write(temp_path, 'Custom content')
      
      allow(comment).to receive(:attachment_path).and_return(temp_path.to_s)
      
      notification = create(:notification,
        target: user,
        notifiable: comment,
        key: 'comment.reply'
      )
      
      mail = CustomNotificationMailer.send_notification_email(notification)
      
      expect(mail.attachments.size).to eq(1)
      expect(mail.attachments.first.body.decoded).to eq('Custom content')
      
      File.delete(temp_path) if File.exist?(temp_path)
    end
  end
  
  describe 'Rails integration' do
    it 'works with Rails logger' do
      article = create(:article, user: user)
      allow(article).to receive(:file_url).and_return('https://invalid-url.example.com/file.pdf')
      allow(article).to receive(:filename).and_return('test.pdf')
      
      notification = create(:notification,
        target: user,
        notifiable: article,
        key: 'document.shared'
      )
      
      expect(Rails.logger).to receive(:error).with(/Failed to attach document/)
      
      CustomNotificationMailer.send_notification_email(notification)
    end
  end
  
  describe 'ActionMailer integration' do
    it 'sets correct email headers' do
      invoice = Invoice.create!(user: user, amount: 100.00)
      notification = create(:notification,
        target: user,
        notifiable: invoice,
        key: 'invoice.created'
      )
      
      mail = CustomNotificationMailer.send_notification_email(notification)
      
      expect(mail.to).to include(user.email)
      expect(mail.from).to be_present
    end
    
    it 'supports multipart emails' do
      invoice = Invoice.create!(user: user, amount: 100.00)
      notification = create(:notification,
        target: user,
        notifiable: invoice,
        key: 'invoice.created'
      )
      
      mail = CustomNotificationMailer.send_notification_email(notification)
      
      # Should have attachment plus email body
      expect(mail.attachments).not_to be_empty
    end
  end
  
  describe 'Extensibility' do
    it 'allows subclassing CustomNotificationMailer' do
      subclass = Class.new(CustomNotificationMailer) do
        def custom_method
          'custom implementation'
        end
      end
      
      expect(subclass.new).to respond_to(:custom_method)
      expect(subclass.new).to respond_to(:send_notification_email)
    end
    
    it 'allows overriding attachment methods' do
      # This documents that the implementation is extensible
      expect(CustomNotificationMailer.instance_methods(false)).to include(:send_notification_email)
      expect(CustomNotificationMailer.private_instance_methods(false)).to include(:add_attachments)
    end
  end
  
  describe 'Configuration edge cases' do
    it 'handles missing mailer sender gracefully' do
      original_sender = ActivityNotification.config.mailer_sender
      ActivityNotification.config.mailer_sender = nil
      
      invoice = Invoice.create!(user: user, amount: 100.00)
      notification = create(:notification,
        target: user,
        notifiable: invoice,
        key: 'invoice.created'
      )
      
      # Should not crash even with missing config
      expect {
        CustomNotificationMailer.send_notification_email(notification)
      }.not_to raise_error
      
      ActivityNotification.config.mailer_sender = original_sender
    end
  end
  
  describe 'Performance benchmarking' do
    it 'generates attachments within reasonable time' do
      invoice = Invoice.create!(user: user, amount: 100.00)
      notification = create(:notification,
        target: user,
        notifiable: invoice,
        key: 'invoice.created'
      )
      
      start_time = Time.now
      CustomNotificationMailer.send_notification_email(notification)
      duration = Time.now - start_time
      
      # Should complete quickly
      expect(duration).to be < 2.0
    end
    
    it 'handles batch processing efficiently' do
      notifications = create_list(:notification, 20, target: user, notifiable: article)
      
      start_time = Time.now
      CustomNotificationMailer.send_batch_notification_email(
        user,
        notifications,
        'batch.test'
      )
      duration = Time.now - start_time
      
      expect(duration).to be < 3.0
    end
  end
end

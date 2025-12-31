require 'rails_helper'

describe CustomNotificationMailer, type: :mailer do
  let(:user) { create(:user) }
  let(:article) { create(:article, user: user) }
  
  describe 'email attachments' do
    context 'with invoice notifications' do
      let(:invoice) do
        Invoice.create!(
          user: user,
          amount: 250.00,
          status: 'pending',
          description: 'Test invoice'
        )
      end
      
      let(:notification) do
        create(:notification,
          target: user,
          notifiable: invoice,
          key: 'invoice.created'
        )
      end
      
      it 'attaches invoice PDF to the email' do
        mail = CustomNotificationMailer.send_notification_email(notification)
        
        expect(mail.attachments.size).to eq(1)
        expect(mail.attachments.first.filename).to match(/invoice_#{invoice.id}.pdf/)
        expect(mail.attachments.first.content_type).to match(/application\/pdf/)
      end
      
      it 'includes invoice details in the email body' do
        mail = CustomNotificationMailer.send_notification_email(notification)
        
        expect(mail.body.encoded).to include("Invoice ##{invoice.id}")
      end
    end
    
    context 'with report notifications' do
      let(:notification) do
        create(:notification,
          target: user,
          notifiable: article,
          key: 'report.completed'
        )
      end
      
      it 'attaches report PDF to the email' do
        mail = CustomNotificationMailer.send_notification_email(notification)
        
        expect(mail.attachments.size).to eq(1)
        expect(mail.attachments.first.filename).to eq('report.pdf')
        expect(mail.attachments.first.content_type).to match(/application\/pdf/)
      end
      
      it 'generates report content' do
        mail = CustomNotificationMailer.send_notification_email(notification)
        attachment = mail.attachments.first
        
        expect(attachment.body.decoded).to include("PDF Report for notification #{notification.id}")
        expect(attachment.body.decoded).to include(notification.notifiable_type)
      end
    end
    
    context 'with monthly report notifications' do
      let(:notification) do
        create(:notification,
          target: user,
          notifiable: article,
          key: 'report.monthly'
        )
      end
      
      it 'attaches both PDF and CSV files' do
        mail = CustomNotificationMailer.send_notification_email(notification)
        
        expect(mail.attachments.size).to eq(2)
        
        pdf_attachment = mail.attachments.find { |a| a.filename == 'monthly_report.pdf' }
        csv_attachment = mail.attachments.find { |a| a.filename == 'monthly_data.csv' }
        
        expect(pdf_attachment).to be_present
        expect(csv_attachment).to be_present
        
        expect(pdf_attachment.content_type).to match(/application\/pdf/)
        expect(csv_attachment.content_type).to match(/text\/csv/)
      end
      
      it 'includes user information in the report' do
        mail = CustomNotificationMailer.send_notification_email(notification)
        pdf_attachment = mail.attachments.find { |a| a.filename == 'monthly_report.pdf' }
        
        expect(pdf_attachment.body.decoded).to include("Monthly Report")
        expect(pdf_attachment.body.decoded).to include(user.class.name)
      end
    end
    
    context 'with batch notifications' do
      let(:notifications) do
        create_list(:notification, 3,
          target: user,
          notifiable: article
        )
      end
      
      it 'attaches summary PDF to batch email' do
        mail = CustomNotificationMailer.send_batch_notification_email(
          user,
          notifications,
          'batch.daily_summary'
        )
        
        expect(mail.attachments.size).to eq(1)
        expect(mail.attachments.first.filename).to eq('notification_summary.pdf')
        expect(mail.attachments.first.content_type).to match(/application\/pdf/)
      end
      
      it 'includes all notifications in summary' do
        mail = CustomNotificationMailer.send_batch_notification_email(
          user,
          notifications,
          'batch.daily_summary'
        )
        
        attachment = mail.attachments.first
        summary_content = attachment.body.decoded
        
        expect(summary_content).to include("Batch Notification Summary")
        expect(summary_content).to include("Total notifications: #{notifications.count}")
        
        notifications.each_with_index do |notification, index|
          expect(summary_content).to include("#{index + 1}.")
          expect(summary_content).to include(notification.key)
        end
      end
    end
    
    context 'with filesystem attachments' do
      let(:comment) { create(:comment, article: article, user: user) }
      let(:notification) do
        create(:notification,
          target: user,
          notifiable: comment,
          key: 'comment.reply'
        )
      end
      
      context 'when attachment file exists' do
        let(:attachment_path) { Rails.root.join('tmp', 'test_attachment.pdf') }
        
        before do
          FileUtils.mkdir_p(File.dirname(attachment_path))
          File.write(attachment_path, 'Test PDF content')
          allow(comment).to receive(:attachment_path).and_return(attachment_path.to_s)
        end
        
        after do
          File.delete(attachment_path) if File.exist?(attachment_path)
        end
        
        it 'attaches the file from filesystem' do
          mail = CustomNotificationMailer.send_notification_email(notification)
          
          expect(mail.attachments.size).to eq(1)
          expect(mail.attachments.first.filename).to eq('test_attachment.pdf')
          expect(mail.attachments.first.body.decoded).to eq('Test PDF content')
        end
      end
      
      context 'when attachment file does not exist' do
        before do
          allow(comment).to receive(:attachment_path).and_return('/non/existent/path.pdf')
        end
        
        it 'does not attach any files' do
          mail = CustomNotificationMailer.send_notification_email(notification)
          
          expect(mail.attachments.size).to eq(0)
        end
      end
    end
    
    context 'error handling' do
      let(:notification) do
        create(:notification,
          target: user,
          notifiable: article,
          key: 'document.shared'
        )
      end
      
      context 'when remote file download fails' do
        before do
          allow(article).to receive(:file_url).and_return('https://invalid-url.com/file.pdf')
          allow(article).to receive(:filename).and_return('document.pdf')
        end
        
        it 'sends email without attachment and logs error' do
          expect(Rails.logger).to receive(:error).with(/Failed to attach document/)
          
          mail = CustomNotificationMailer.send_notification_email(notification)
          
          # Email should still be sent, just without attachment
          expect(mail).to be_present
          expect(mail.attachments.size).to eq(0)
        end
      end
    end
  end
  
  describe '#add_attachments' do
    let(:notification) do
      create(:notification,
        target: user,
        notifiable: article,
        key: 'test.notification'
      )
    end
    
    let(:mailer) { CustomNotificationMailer.new }
    
    it 'is called before sending email' do
      expect_any_instance_of(CustomNotificationMailer)
        .to receive(:add_attachments).with(notification)
      
      CustomNotificationMailer.send_notification_email(notification)
    end
  end
  
  describe '#add_batch_attachments' do
    let(:notifications) do
      create_list(:notification, 2, target: user, notifiable: article)
    end
    
    it 'is called before sending batch email' do
      expect_any_instance_of(CustomNotificationMailer)
        .to receive(:add_batch_attachments).with(user, notifications)
      
      CustomNotificationMailer.send_batch_notification_email(
        user,
        notifications,
        'batch.test'
      )
    end
  end
  
  describe 'comprehensive attachment scenarios' do
    context 'with inline image attachments' do
      let(:article) { create(:article, user: user) }
      let(:logo_path) { Rails.root.join('tmp', 'logo.png') }
      
      before do
        FileUtils.mkdir_p(File.dirname(logo_path))
        File.write(logo_path, 'PNG content')
        allow(article).to receive(:logo_path).and_return(logo_path.to_s)
      end
      
      after do
        File.delete(logo_path) if File.exist?(logo_path)
      end
      
      it 'attaches inline images' do
        notification = create(:notification,
          target: user,
          notifiable: article,
          key: 'test.notification'
        )
        
        mail = CustomNotificationMailer.send_notification_email(notification)
        
        inline_attachment = mail.attachments.inline.find { |a| a.filename == 'logo.png' }
        expect(inline_attachment).to be_present
        expect(inline_attachment.body.decoded).to eq('PNG content')
      end
    end
    
    context 'with missing inline image' do
      let(:article) { create(:article, user: user) }
      
      before do
        allow(article).to receive(:logo_path).and_return('/non/existent/logo.png')
      end
      
      it 'does not attach missing inline images' do
        notification = create(:notification,
          target: user,
          notifiable: article,
          key: 'test.notification'
        )
        
        mail = CustomNotificationMailer.send_notification_email(notification)
        
        expect(mail.attachments.inline.count).to eq(0)
      end
    end
    
    context 'with multiple attachment types in one email' do
      let(:comment) { create(:comment, article: article, user: user) }
      let(:attachment_path) { Rails.root.join('tmp', 'document.pdf') }
      let(:logo_path) { Rails.root.join('tmp', 'company_logo.png') }
      
      before do
        FileUtils.mkdir_p(Rails.root.join('tmp'))
        File.write(attachment_path, 'Document content')
        File.write(logo_path, 'Logo content')
        allow(comment).to receive(:attachment_path).and_return(attachment_path.to_s)
        allow(comment).to receive(:logo_path).and_return(logo_path.to_s)
      end
      
      after do
        File.delete(attachment_path) if File.exist?(attachment_path)
        File.delete(logo_path) if File.exist?(logo_path)
      end
      
      it 'includes both regular and inline attachments' do
        notification = create(:notification,
          target: user,
          notifiable: comment,
          key: 'comment.reply'
        )
        
        mail = CustomNotificationMailer.send_notification_email(notification)
        
        # Check regular attachment
        expect(mail.attachments.count).to eq(2)
        regular_attachment = mail.attachments.find { |a| a.filename == 'document.pdf' && !a.inline? }
        expect(regular_attachment).to be_present
        
        # Check inline attachment
        inline_attachment = mail.attachments.inline.find { |a| a.filename == 'company_logo.png' }
        expect(inline_attachment).to be_present
      end
    end
    
    context 'with notifiable not responding to attachment methods' do
      let(:article) { create(:article, user: user) }
      
      it 'handles gracefully when notifiable does not have attachment_path' do
        notification = create(:notification,
          target: user,
          notifiable: article,
          key: 'article.published'
        )
        
        expect {
          mail = CustomNotificationMailer.send_notification_email(notification)
          expect(mail).to be_present
        }.not_to raise_error
      end
    end
    
    context 'monthly report uses MonthlyReportGenerator' do
      let!(:notifications) do
        create_list(:notification, 5, target: user)
      end
      
      before do
        notifications.take(3).each { |n| n.open! }
      end
      
      it 'generates PDF using MonthlyReportGenerator' do
        notification = create(:notification,
          target: user,
          notifiable: article,
          key: 'report.monthly'
        )
        
        mail = CustomNotificationMailer.send_notification_email(notification)
        pdf_attachment = mail.attachments.find { |a| a.filename == 'monthly_report.pdf' }
        
        pdf_content = pdf_attachment.body.decoded
        expect(pdf_content).to include('MONTHLY ACTIVITY REPORT')
        expect(pdf_content).to include(user.class.name)
        expect(pdf_content).to include("Total Notifications: #{user.notifications.count}")
      end
      
      it 'generates CSV using MonthlyReportGenerator' do
        notification = create(:notification,
          target: user,
          notifiable: article,
          key: 'report.monthly'
        )
        
        mail = CustomNotificationMailer.send_notification_email(notification)
        csv_attachment = mail.attachments.find { |a| a.filename == 'monthly_data.csv' }
        
        csv_content = csv_attachment.body.decoded
        expect(csv_content).to include('Month,Total Notifications,Opened,Unopened')
        expect(csv_content).to include('Notification Type,Count')
      end
    end
    
    context 'with empty or nil attachment paths' do
      let(:comment) { create(:comment, article: article, user: user) }
      
      it 'handles empty attachment_path' do
        allow(comment).to receive(:attachment_path).and_return('')
        
        notification = create(:notification,
          target: user,
          notifiable: comment,
          key: 'comment.reply'
        )
        
        expect {
          mail = CustomNotificationMailer.send_notification_email(notification)
          expect(mail.attachments.count).to eq(0)
        }.not_to raise_error
      end
      
      it 'handles nil attachment_path' do
        allow(comment).to receive(:attachment_path).and_return(nil)
        
        notification = create(:notification,
          target: user,
          notifiable: comment,
          key: 'comment.reply'
        )
        
        expect {
          mail = CustomNotificationMailer.send_notification_email(notification)
          expect(mail.attachments.count).to eq(0)
        }.not_to raise_error
      end
    end
  end
  
  describe 'private methods' do
    let(:mailer) { CustomNotificationMailer.new }
    
    describe '#generate_report_pdf' do
      let(:notification) do
        create(:notification,
          target: user,
          notifiable: article,
          key: 'report.completed'
        )
      end
      
      it 'generates report content with all details' do
        pdf_content = mailer.send(:generate_report_pdf, notification)
        
        expect(pdf_content).to include("PDF Report for notification #{notification.id}")
        expect(pdf_content).to include("Notifiable: #{notification.notifiable_type} ##{notification.notifiable_id}")
        expect(pdf_content).to include("Target: #{notification.target_type} ##{notification.target_id}")
        expect(pdf_content).to include("Created:")
      end
    end
    
    describe '#generate_batch_summary_pdf' do
      let(:notifications) do
        create_list(:notification, 3, target: user, notifiable: article)
      end
      
      it 'generates comprehensive batch summary' do
        summary = mailer.send(:generate_batch_summary_pdf, user, notifications)
        
        expect(summary).to include('Batch Notification Summary')
        expect(summary).to include("Target: #{user.class.name} ##{user.id}")
        expect(summary).to include("Total notifications: #{notifications.count}")
        
        notifications.each_with_index do |notification, index|
          expect(summary).to include("#{index + 1}.")
          expect(summary).to include(notification.key)
          expect(summary).to include("#{notification.notifiable_type} ##{notification.notifiable_id}")
        end
      end
    end
    
    describe '#attach_shared_document' do
      let(:article) { create(:article, user: user) }
      let(:notification) do
        create(:notification,
          target: user,
          notifiable: article,
          key: 'document.shared'
        )
      end
      
      context 'when notifiable does not respond to file_url' do
        it 'does not attempt to attach anything' do
          mail = CustomNotificationMailer.send_notification_email(notification)
          expect(mail.attachments.count).to eq(0)
        end
      end
      
      context 'when file_url is empty' do
        before do
          allow(article).to receive(:file_url).and_return('')
        end
        
        it 'does not attempt to attach anything' do
          mail = CustomNotificationMailer.send_notification_email(notification)
          expect(mail.attachments.count).to eq(0)
        end
      end
      
      context 'when file_url is nil' do
        before do
          allow(article).to receive(:file_url).and_return(nil)
        end
        
        it 'does not attempt to attach anything' do
          mail = CustomNotificationMailer.send_notification_email(notification)
          expect(mail.attachments.count).to eq(0)
        end
      end
    end
  end
end

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
end

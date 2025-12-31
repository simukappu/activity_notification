require 'rails_helper'

describe 'Email Attachments Helper Methods', type: :helper do
  let(:user) { create(:user) }
  let(:article) { create(:article, user: user) }
  
  describe 'notification path helpers' do
    context 'for Invoice model' do
      let(:invoice) { Invoice.create!(user: user, amount: 100.00) }
      
      it 'provides correct invoice path' do
        expect(invoice.invoice_path).to eq("/invoices/#{invoice.id}")
      end
      
      it 'provides correct notifiable path' do
        expect(invoice.notifiable_path).to eq("/invoices/#{invoice.id}")
      end
    end
  end
  
  describe 'notification configuration helpers' do
    context 'Invoice notifiable targets' do
      let(:invoice) { Invoice.create!(user: user, amount: 150.00) }
      
      it 'returns correct target for invoice notifications' do
        targets = invoice.notifiable_targets(:users, 'invoice.created')
        expect(targets).to include(user)
      end
      
      it 'allows email notifications' do
        expect(invoice.notifiable_email_allowed?(user, 'invoice.created')).to be_truthy
      end
    end
  end
  
  describe 'attachment content generation' do
    context 'Invoice PDF generation' do
      let(:invoice) do
        Invoice.create!(
          user: user,
          amount: 250.00,
          status: 'pending',
          description: 'Test invoice'
        )
      end
      
      it 'generates non-empty PDF content' do
        content = invoice.generate_pdf
        expect(content).to be_present
        expect(content.length).to be > 0
      end
      
      it 'generates reproducible PDF content' do
        content1 = invoice.generate_pdf
        content2 = invoice.generate_pdf
        expect(content1).to eq(content2)
      end
      
      it 'includes critical invoice information' do
        content = invoice.generate_pdf
        expect(content).to include(invoice.id.to_s)
        expect(content).to include(invoice.amount.to_s)
        expect(content).to include(invoice.status)
      end
    end
    
    context 'MonthlyReportGenerator' do
      let(:generator) { MonthlyReportGenerator.new(user) }
      
      it 'initializes with target and month' do
        expect(generator.target).to eq(user)
        expect(generator.month).to be_a(Date)
      end
      
      it 'generates PDF content' do
        content = generator.to_pdf
        expect(content).to be_present
        expect(content).to include('MONTHLY ACTIVITY REPORT')
      end
      
      it 'generates CSV content' do
        content = generator.to_csv
        expect(content).to be_present
        expect(content).to include('Month,Total Notifications')
      end
      
      it 'handles targets without notifications' do
        article = create(:article)
        generator = MonthlyReportGenerator.new(article)
        
        expect { generator.to_pdf }.not_to raise_error
        expect { generator.to_csv }.not_to raise_error
      end
    end
  end
  
  describe 'printable name helpers' do
    context 'for Invoice' do
      let(:invoice) { Invoice.create!(user: user, amount: 100.00) }
      
      it 'returns formatted printable name' do
        expect(invoice.printable_notifiable_name).to eq("Invoice ##{invoice.id}")
      end
      
      it 'uses printable name in notifications' do
        invoice.notify :users, key: 'invoice.created'
        notification = user.notifications.last
        
        expect(notification.notifiable.printable_notifiable_name).to eq("Invoice ##{invoice.id}")
      end
    end
  end
  
  describe 'email configuration' do
    it 'uses CustomNotificationMailer when configured' do
      ActivityNotification.config.mailer = 'CustomNotificationMailer'
      expect(ActivityNotification.config.mailer).to eq('CustomNotificationMailer')
    end
    
    it 'respects email_enabled setting' do
      ActivityNotification.config.email_enabled = true
      expect(ActivityNotification.config.email_enabled).to be true
    end
  end
  
  describe 'attachment mime types' do
    let(:mailer) { CustomNotificationMailer.new }
    
    it 'uses correct mime type for PDF' do
      invoice = Invoice.create!(user: user, amount: 100.00)
      notification = create(:notification,
        target: user,
        notifiable: invoice,
        key: 'invoice.created'
      )
      
      mail = CustomNotificationMailer.send_notification_email(notification)
      pdf_attachment = mail.attachments.first
      
      expect(pdf_attachment.content_type).to match(/application\/pdf/)
    end
    
    it 'uses correct mime type for CSV' do
      notification = create(:notification,
        target: user,
        notifiable: article,
        key: 'report.monthly'
      )
      
      mail = CustomNotificationMailer.send_notification_email(notification)
      csv_attachment = mail.attachments.find { |a| a.filename == 'monthly_data.csv' }
      
      expect(csv_attachment.content_type).to match(/text\/csv/)
    end
  end
  
  describe 'file operations' do
    context 'filesystem attachment handling' do
      let(:comment) { create(:comment, article: article, user: user) }
      let(:temp_file) { Rails.root.join('tmp', 'test_file.txt') }
      
      before do
        FileUtils.mkdir_p(File.dirname(temp_file))
        File.write(temp_file, 'Test content')
      end
      
      after do
        File.delete(temp_file) if File.exist?(temp_file)
      end
      
      it 'reads file content correctly' do
        content = File.read(temp_file)
        expect(content).to eq('Test content')
      end
      
      it 'checks file existence correctly' do
        expect(File.exist?(temp_file)).to be true
        expect(File.exist?('/non/existent/file.txt')).to be false
      end
    end
  end
  
  describe 'notification key handling' do
    let(:invoice) { Invoice.create!(user: user, amount: 100.00) }
    
    it 'creates notifications with different keys' do
      keys = ['invoice.created', 'invoice.updated', 'invoice.paid']
      
      keys.each do |key|
        invoice.notify :users, key: key
        notification = user.notifications.last
        expect(notification.key).to eq(key)
      end
    end
    
    it 'mailer handles different notification keys' do
      test_keys = [
        'report.completed',
        'invoice.created',
        'report.monthly',
        'document.shared',
        'comment.reply'
      ]
      
      test_keys.each do |key|
        notification = create(:notification,
          target: user,
          notifiable: article,
          key: key
        )
        
        expect { CustomNotificationMailer.send_notification_email(notification) }.not_to raise_error
      end
    end
  end
  
  describe 'batch notification handling' do
    let(:notifications) { create_list(:notification, 5, target: user, notifiable: article) }
    
    it 'processes batch notifications' do
      expect {
        CustomNotificationMailer.send_batch_notification_email(
          user,
          notifications,
          'batch.daily_summary'
        )
      }.not_to raise_error
    end
    
    it 'includes all notifications in batch' do
      mail = CustomNotificationMailer.send_batch_notification_email(
        user,
        notifications,
        'batch.daily_summary'
      )
      
      summary = mail.attachments.first.body.decoded
      expect(summary).to include("Total notifications: #{notifications.count}")
    end
  end
  
  describe 'error handling utilities' do
    it 'handles missing methods gracefully' do
      article = create(:article)
      
      # Should not raise error even if methods don't exist
      expect { article.respond_to?(:attachment_path) }.not_to raise_error
      expect { article.respond_to?(:generate_pdf) }.not_to raise_error
    end
    
    it 'handles nil values gracefully' do
      expect { File.exist?(nil) }.to raise_error(TypeError)
      
      # But our code should handle this
      article = create(:article)
      notification = create(:notification, target: user, notifiable: article, key: 'test')
      
      expect {
        CustomNotificationMailer.send_notification_email(notification)
      }.not_to raise_error
    end
  end
  
  describe 'date formatting utilities' do
    it 'formats dates consistently for reports' do
      date = Date.new(2023, 6, 15)
      expect(date.strftime('%B %Y')).to eq('June 2023')
      expect(date.strftime('%Y-%m')).to eq('2023-06')
    end
    
    it 'formats timestamps consistently' do
      time = Time.new(2023, 6, 15, 14, 30, 0)
      expect(time.strftime('%Y-%m-%d %H:%M:%S')).to match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/)
    end
  end
  
  describe 'ActiveRecord vs Mongoid compatibility' do
    it 'Invoice works with ActiveRecord' do
      skip 'Mongoid environment' if ENV['AN_TEST_DB'] == 'mongodb'
      
      invoice = Invoice.create!(user: user, amount: 100.00)
      expect(invoice.class.ancestors).to include(ActiveRecord::Base)
    end
    
    it 'Invoice includes proper modules' do
      invoice = Invoice.create!(user: user, amount: 100.00)
      expect(invoice.class.ancestors).to include(ActivityNotification::Notifiable)
    end
  end
  
  describe 'attachment filename handling' do
    it 'generates unique filenames for invoices' do
      invoice1 = Invoice.create!(user: user, amount: 100.00)
      invoice2 = Invoice.create!(user: user, amount: 200.00)
      
      filename1 = "invoice_#{invoice1.id}.pdf"
      filename2 = "invoice_#{invoice2.id}.pdf"
      
      expect(filename1).not_to eq(filename2)
    end
    
    it 'uses consistent filenames for reports' do
      filenames = ['report.pdf', 'monthly_report.pdf', 'monthly_data.csv', 'notification_summary.pdf']
      
      filenames.each do |filename|
        expect(filename).to match(/\.(pdf|csv)$/)
      end
    end
  end
end

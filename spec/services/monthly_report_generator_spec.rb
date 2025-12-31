require 'rails_helper'

describe MonthlyReportGenerator do
  let(:user) { create(:user) }
  let(:month) { Date.current.last_month }
  let(:generator) { MonthlyReportGenerator.new(user, month) }
  
  describe '#initialize' do
    it 'sets target and month' do
      expect(generator.target).to eq(user)
      expect(generator.month).to eq(month)
    end
    
    context 'with default month' do
      let(:generator) { MonthlyReportGenerator.new(user) }
      
      it 'defaults to last month' do
        expect(generator.month).to eq(Date.current.last_month)
      end
    end
  end
  
  describe '#to_pdf' do
    let(:pdf_content) { generator.to_pdf }
    
    it 'generates PDF content as string' do
      expect(pdf_content).to be_a(String)
    end
    
    it 'includes report header' do
      expect(pdf_content).to include('MONTHLY ACTIVITY REPORT')
    end
    
    it 'includes report period' do
      expect(pdf_content).to include("Report Period: #{month.strftime('%B %Y')}")
    end
    
    it 'includes generation timestamp' do
      expect(pdf_content).to include('Generated:')
    end
    
    it 'includes target information' do
      expect(pdf_content).to include("Target: #{user.class.name} ##{user.id}")
      expect(pdf_content).to include("Name: #{user.name}")
      expect(pdf_content).to include("Email: #{user.email}")
    end
    
    it 'includes activity summary section' do
      expect(pdf_content).to include('ACTIVITY SUMMARY')
    end
    
    context 'with notifications' do
      let!(:notifications) do
        create_list(:notification, 5, target: user)
      end
      
      let!(:opened_notifications) do
        notifications.take(3).each { |n| n.open! }
      end
      
      it 'includes total notification count' do
        expect(pdf_content).to include("Total Notifications: #{user.notifications.count}")
      end
      
      it 'includes opened notification count' do
        opened_count = user.notifications.opened_only.count
        expect(pdf_content).to include("Opened: #{opened_count}")
      end
      
      it 'includes unopened notification count' do
        unopened_count = user.notifications.unopened_only.count
        expect(pdf_content).to include("Unopened: #{unopened_count}")
      end
      
      it 'includes notification breakdown by type' do
        expect(pdf_content).to include('NOTIFICATION BREAKDOWN BY TYPE')
      end
    end
    
    context 'without notifications' do
      it 'shows zero counts' do
        expect(pdf_content).to include("Total Notifications: 0")
      end
    end
    
    it 'includes end of report marker' do
      expect(pdf_content).to include('End of Report')
    end
  end
  
  describe '#to_csv' do
    let(:csv_content) { generator.to_csv }
    
    it 'generates CSV content as string' do
      expect(csv_content).to be_a(String)
    end
    
    it 'includes CSV header row' do
      expect(csv_content).to include('Month,Total Notifications,Opened,Unopened')
    end
    
    it 'includes month in correct format' do
      expect(csv_content).to include(month.strftime('%Y-%m'))
    end
    
    context 'with notifications' do
      let!(:notifications) do
        create_list(:notification, 5, target: user)
      end
      
      let!(:opened_notifications) do
        notifications.take(2).each { |n| n.open! }
      end
      
      it 'includes notification counts' do
        total = user.notifications.count
        opened = user.notifications.opened_only.count
        unopened = user.notifications.unopened_only.count
        
        expect(csv_content).to include("#{total},#{opened},#{unopened}")
      end
      
      it 'includes notification breakdown section' do
        expect(csv_content).to include('Notification Type,Count')
      end
    end
    
    context 'without notifications' do
      it 'shows zero counts' do
        expect(csv_content).to include(',0,0,0')
      end
    end
  end
  
  describe 'with different target types' do
    let(:article) { create(:article) }
    let(:generator) { MonthlyReportGenerator.new(article, month) }
    
    it 'works with targets that do not have notifications association' do
      pdf_content = generator.to_pdf
      expect(pdf_content).to include("Target: Article ##{article.id}")
    end
  end
  
  describe 'edge cases and error handling' do
    context 'with different date formats' do
      let(:specific_date) { Date.new(2023, 6, 15) }
      let(:generator) { MonthlyReportGenerator.new(user, specific_date) }
      
      it 'formats month correctly for different dates' do
        pdf_content = generator.to_pdf
        expect(pdf_content).to include('June 2023')
      end
      
      it 'uses correct month in CSV' do
        csv_content = generator.to_csv
        expect(csv_content).to include('2023-06')
      end
    end
    
    context 'with notifications from different months' do
      let!(:current_month_notifications) do
        create_list(:notification, 3, target: user, created_at: month.beginning_of_month + 5.days)
      end
      
      let!(:previous_month_notifications) do
        create_list(:notification, 5, target: user, created_at: month.beginning_of_month - 10.days)
      end
      
      it 'counts all notifications in total' do
        pdf_content = generator.to_pdf
        expect(pdf_content).to include("Total Notifications: 8")
      end
    end
    
    context 'with large number of notifications' do
      let!(:notifications) do
        create_list(:notification, 100, target: user)
      end
      
      it 'handles large datasets' do
        expect { generator.to_pdf }.not_to raise_error
        expect { generator.to_csv }.not_to raise_error
      end
      
      it 'includes correct count' do
        pdf_content = generator.to_pdf
        expect(pdf_content).to include("Total Notifications: 100")
      end
    end
    
    context 'with diverse notification keys' do
      let!(:notification_types) do
        [
          create(:notification, target: user, key: 'article.created'),
          create(:notification, target: user, key: 'article.updated'),
          create(:notification, target: user, key: 'comment.posted'),
          create(:notification, target: user, key: 'comment.replied'),
          create(:notification, target: user, key: 'invoice.created'),
        ]
      end
      
      it 'includes breakdown of all notification types in PDF' do
        pdf_content = generator.to_pdf
        expect(pdf_content).to include('NOTIFICATION BREAKDOWN BY TYPE')
        expect(pdf_content).to include('article.created')
        expect(pdf_content).to include('comment.posted')
        expect(pdf_content).to include('invoice.created')
      end
      
      it 'includes breakdown in CSV' do
        csv_content = generator.to_csv
        expect(csv_content).to include('Notification Type,Count')
        expect(csv_content).to include('article.created')
        expect(csv_content).to include('comment.posted')
      end
    end
    
    context 'with user without email' do
      let(:user_without_email) do
        u = create(:user)
        allow(u).to receive(:respond_to?).with(:email).and_return(false)
        u
      end
      let(:generator) { MonthlyReportGenerator.new(user_without_email) }
      
      it 'generates PDF without email field' do
        pdf_content = generator.to_pdf
        expect(pdf_content).to include("Target: User ##{user_without_email.id}")
        expect(pdf_content).not_to include('Email:')
      end
    end
    
    context 'with user without name' do
      let(:user_without_name) do
        u = create(:user)
        allow(u).to receive(:respond_to?).with(:name).and_return(false)
        u
      end
      let(:generator) { MonthlyReportGenerator.new(user_without_name) }
      
      it 'generates PDF without name field' do
        pdf_content = generator.to_pdf
        expect(pdf_content).to include("Target: User ##{user_without_name.id}")
        expect(pdf_content).not_to include('Name:')
      end
    end
    
    context 'CSV generation details' do
      let!(:notifications) do
        create_list(:notification, 10, target: user)
      end
      
      before do
        notifications.take(7).each { |n| n.open! }
      end
      
      it 'generates valid CSV format' do
        csv_content = generator.to_csv
        rows = csv_content.split("\n")
        
        # Check header
        expect(rows[0]).to eq('Month,Total Notifications,Opened,Unopened')
        
        # Check data row format
        data_row = rows[1].split(',')
        expect(data_row.length).to eq(4)
        expect(data_row[1].to_i).to eq(10)
        expect(data_row[2].to_i).to eq(7)
        expect(data_row[3].to_i).to eq(3)
      end
      
      it 'includes empty row separator' do
        csv_content = generator.to_csv
        rows = csv_content.split("\n")
        expect(rows).to include('')
      end
      
      it 'includes notification type header' do
        csv_content = generator.to_csv
        expect(csv_content).to include('Notification Type,Count')
      end
    end
    
    context 'PDF generation details' do
      it 'includes proper section headers' do
        pdf_content = generator.to_pdf
        expect(pdf_content).to include('MONTHLY ACTIVITY REPORT')
        expect(pdf_content).to include('ACTIVITY SUMMARY')
        expect(pdf_content).to include('NOTIFICATION BREAKDOWN BY TYPE')
      end
      
      it 'includes separators' do
        pdf_content = generator.to_pdf
        expect(pdf_content).to include('=' * 60)
        expect(pdf_content).to include('-' * 60)
      end
      
      it 'includes end of report marker' do
        pdf_content = generator.to_pdf
        expect(pdf_content).to end_with('End of Report')
      end
      
      it 'uses proper timestamp format' do
        pdf_content = generator.to_pdf
        expect(pdf_content).to match(/Generated: \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/)
      end
    end
    
    context 'when notifications query fails' do
      before do
        allow(user).to receive(:notifications).and_raise(StandardError.new('Database error'))
      end
      
      it 'handles errors gracefully in PDF generation' do
        expect { generator.to_pdf }.not_to raise_error
      end
      
      it 'handles errors gracefully in CSV generation' do
        expect { generator.to_csv }.not_to raise_error
      end
    end
    
    context 'with nil month parameter' do
      let(:generator) { MonthlyReportGenerator.new(user, nil) }
      
      it 'uses default month' do
        expect(generator.month).to eq(Date.current.last_month)
      end
    end
    
    context 'with future month' do
      let(:future_month) { Date.current + 2.months }
      let(:generator) { MonthlyReportGenerator.new(user, future_month) }
      
      it 'accepts future month' do
        pdf_content = generator.to_pdf
        expect(pdf_content).to include(future_month.strftime('%B %Y'))
      end
    end
    
    context 'with very old month' do
      let(:old_month) { Date.new(2010, 1, 1) }
      let(:generator) { MonthlyReportGenerator.new(user, old_month) }
      
      it 'accepts old dates' do
        pdf_content = generator.to_pdf
        expect(pdf_content).to include('January 2010')
      end
    end
  end
end

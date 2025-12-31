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
end

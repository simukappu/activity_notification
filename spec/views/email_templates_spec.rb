require 'rails_helper'

describe 'Email Template Views', type: :view do
  let(:user) { create(:user) }
  
  describe 'monthly report email templates' do
    let(:article) { create(:article, user: user) }
    let(:notification) do
      create(:notification,
        target: user,
        notifiable: article,
        key: 'report.monthly'
      )
    end
    
    before do
      assign(:target, user)
      assign(:notification, notification)
      create_list(:notification, 10, target: user)
      user.notifications.take(6).each { |n| n.open! }
    end
    
    context 'HTML template' do
      it 'renders without errors' do
        expect {
          render template: 'activity_notification/mailer/users/report/monthly.html.erb'
        }.not_to raise_error
      end
      
      it 'includes user greeting' do
        render template: 'activity_notification/mailer/users/report/monthly.html.erb'
        expect(rendered).to include("Dear #{user.name}")
      end
      
      it 'includes month information' do
        render template: 'activity_notification/mailer/users/report/monthly.html.erb'
        expect(rendered).to include(Date.current.last_month.strftime('%B %Y'))
      end
      
      it 'includes notification statistics' do
        render template: 'activity_notification/mailer/users/report/monthly.html.erb'
        expect(rendered).to include("Total notifications: #{user.notifications.count}")
        expect(rendered).to include('Opened: 6')
        expect(rendered).to include('Unopened: 4')
      end
      
      it 'includes header styling' do
        render template: 'activity_notification/mailer/users/report/monthly.html.erb'
        expect(rendered).to include('class="header"')
        expect(rendered).to include('background-color: #4CAF50')
      end
      
      it 'includes content section' do
        render template: 'activity_notification/mailer/users/report/monthly.html.erb'
        expect(rendered).to include('class="content"')
      end
      
      it 'includes footer' do
        render template: 'activity_notification/mailer/users/report/monthly.html.erb'
        expect(rendered).to include('class="footer"')
        expect(rendered).to include('automated email')
      end
    end
    
    context 'Text template' do
      it 'renders without errors' do
        expect {
          render template: 'activity_notification/mailer/users/report/monthly.text.erb'
        }.not_to raise_error
      end
      
      it 'includes user greeting' do
        render template: 'activity_notification/mailer/users/report/monthly.text.erb'
        expect(rendered).to include("Dear #{user.name}")
      end
      
      it 'includes month information' do
        render template: 'activity_notification/mailer/users/report/monthly.text.erb'
        expect(rendered).to include(Date.current.last_month.strftime('%B %Y'))
      end
      
      it 'includes notification statistics in plain text' do
        render template: 'activity_notification/mailer/users/report/monthly.text.erb'
        expect(rendered).to include("Total notifications: #{user.notifications.count}")
      end
    end
    
    context 'when user has no notifications' do
      let(:new_user) { create(:user) }
      
      before do
        assign(:target, new_user)
      end
      
      it 'renders HTML template without errors' do
        expect {
          render template: 'activity_notification/mailer/users/report/monthly.html.erb'
        }.not_to raise_error
      end
      
      it 'shows zero counts in HTML' do
        render template: 'activity_notification/mailer/users/report/monthly.html.erb'
        expect(rendered).to include('Total notifications: 0')
      end
    end
  end
  
  describe 'invoice email templates' do
    let(:invoice) do
      Invoice.create!(
        user: user,
        amount: 350.00,
        status: 'pending',
        description: 'Consulting services'
      )
    end
    
    let(:notification) do
      create(:notification,
        target: user,
        notifiable: invoice,
        key: 'invoice.created'
      )
    end
    
    before do
      assign(:target, user)
      assign(:notification, notification)
    end
    
    context 'HTML template' do
      it 'renders without errors' do
        expect {
          render template: 'activity_notification/mailer/users/invoice/created.html.erb'
        }.not_to raise_error
      end
      
      it 'includes user greeting' do
        render template: 'activity_notification/mailer/users/invoice/created.html.erb'
        expect(rendered).to include("Dear #{user.name}")
      end
      
      it 'includes invoice number' do
        render template: 'activity_notification/mailer/users/invoice/created.html.erb'
        expect(rendered).to include("Invoice #: #{invoice.id}")
      end
      
      it 'includes invoice amount' do
        render template: 'activity_notification/mailer/users/invoice/created.html.erb'
        expect(rendered).to include('$350.0')
      end
      
      it 'includes invoice status' do
        render template: 'activity_notification/mailer/users/invoice/created.html.erb'
        expect(rendered).to include('Status:')
        expect(rendered).to include('Pending')
      end
      
      it 'includes invoice date' do
        render template: 'activity_notification/mailer/users/invoice/created.html.erb'
        expect(rendered).to include(invoice.created_at.strftime('%B %d, %Y'))
      end
      
      it 'includes header with proper styling' do
        render template: 'activity_notification/mailer/users/invoice/created.html.erb'
        expect(rendered).to include('class="header"')
        expect(rendered).to include('background-color: #2196F3')
      end
      
      it 'includes invoice details section' do
        render template: 'activity_notification/mailer/users/invoice/created.html.erb'
        expect(rendered).to include('class="invoice-details"')
      end
    end
    
    context 'Text template' do
      it 'renders without errors' do
        expect {
          render template: 'activity_notification/mailer/users/invoice/created.text.erb'
        }.not_to raise_error
      end
      
      it 'includes user greeting in plain text' do
        render template: 'activity_notification/mailer/users/invoice/created.text.erb'
        expect(rendered).to include("Dear #{user.name}")
      end
      
      it 'includes invoice information in plain text' do
        render template: 'activity_notification/mailer/users/invoice/created.text.erb'
        expect(rendered).to include("Invoice #: #{invoice.id}")
        expect(rendered).to include('Amount: $350.0')
      end
    end
    
    context 'with different invoice statuses' do
      it 'displays paid status correctly' do
        invoice.update!(status: 'paid')
        render template: 'activity_notification/mailer/users/invoice/created.html.erb'
        expect(rendered).to include('Paid')
      end
      
      it 'displays cancelled status correctly' do
        invoice.update!(status: 'cancelled')
        render template: 'activity_notification/mailer/users/invoice/created.html.erb'
        expect(rendered).to include('Cancelled')
      end
    end
    
    context 'with large amounts' do
      before do
        invoice.update!(amount: 9999.99)
      end
      
      it 'displays large amounts correctly' do
        render template: 'activity_notification/mailer/users/invoice/created.html.erb'
        expect(rendered).to include('$9999.99')
      end
    end
  end
  
  describe 'template accessibility' do
    let(:article) { create(:article, user: user) }
    let(:notification) do
      create(:notification,
        target: user,
        notifiable: article,
        key: 'report.monthly'
      )
    end
    
    before do
      assign(:target, user)
      assign(:notification, notification)
    end
    
    context 'when target does not respond to name' do
      before do
        allow(user).to receive(:respond_to?).with(:name).and_return(false)
      end
      
      it 'uses fallback greeting in monthly report' do
        render template: 'activity_notification/mailer/users/report/monthly.html.erb'
        expect(rendered).to include('Dear User')
      end
      
      it 'uses fallback greeting in invoice email' do
        invoice = Invoice.create!(user: user, amount: 100.00)
        notification = create(:notification, target: user, notifiable: invoice, key: 'invoice.created')
        assign(:notification, notification)
        
        render template: 'activity_notification/mailer/users/invoice/created.html.erb'
        expect(rendered).to include('Dear Customer')
      end
    end
    
    context 'when target does not have notifications' do
      let(:article_without_notifications) { create(:article) }
      
      before do
        assign(:target, article_without_notifications)
      end
      
      it 'handles missing notifications association gracefully' do
        expect {
          render template: 'activity_notification/mailer/users/report/monthly.html.erb'
        }.not_to raise_error
      end
    end
  end
  
  describe 'email template formatting' do
    let(:article) { create(:article, user: user) }
    let(:notification) do
      create(:notification,
        target: user,
        notifiable: article,
        key: 'report.monthly'
      )
    end
    
    before do
      assign(:target, user)
      assign(:notification, notification)
    end
    
    it 'generates valid HTML' do
      render template: 'activity_notification/mailer/users/report/monthly.html.erb'
      expect(rendered).to include('<!DOCTYPE html>')
      expect(rendered).to include('<html>')
      expect(rendered).to include('</html>')
    end
    
    it 'includes proper character encoding' do
      render template: 'activity_notification/mailer/users/report/monthly.html.erb'
      expect(rendered).to include("charset=UTF-8")
    end
    
    it 'includes CSS styling' do
      render template: 'activity_notification/mailer/users/report/monthly.html.erb'
      expect(rendered).to include('<style>')
      expect(rendered).to include('font-family')
    end
  end
end

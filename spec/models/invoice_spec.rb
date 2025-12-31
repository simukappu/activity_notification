require 'rails_helper'

describe Invoice, type: :model do
  let(:user) { create(:user) }
  
  describe 'associations' do
    it { should belong_to(:user) }
  end
  
  describe 'validations' do
    it { should validate_presence_of(:user) }
  end
  
  describe 'acts_as_notifiable' do
    it 'includes ActivityNotification::Notifiable' do
      expect(Invoice.ancestors).to include(ActivityNotification::Notifiable)
    end
    
    context 'notification configuration' do
      let(:invoice) { Invoice.create!(user: user, amount: 100.00) }
      
      it 'targets the invoice user' do
        targets = invoice.notifiable_targets(:users, 'invoice.created')
        expect(targets).to include(user)
      end
      
      it 'has notifiable_path configured' do
        expect(invoice.notifiable_path).to eq("/invoices/#{invoice.id}")
      end
      
      it 'has email_allowed enabled' do
        expect(invoice.notifiable_email_allowed?(user, 'invoice.created')).to be_truthy
      end
      
      it 'has printable_name configured' do
        expect(invoice.printable_notifiable_name).to eq("Invoice ##{invoice.id}")
      end
    end
  end
  
  describe '#generate_pdf' do
    let(:invoice) do
      Invoice.create!(
        user: user,
        amount: 250.00,
        status: 'pending',
        description: 'Test invoice description'
      )
    end
    
    it 'generates PDF content' do
      pdf_content = invoice.generate_pdf
      
      expect(pdf_content).to be_a(String)
      expect(pdf_content).to include("INVOICE ##{invoice.id}")
      expect(pdf_content).to include("Amount: $250.0")
      expect(pdf_content).to include("Status: pending")
      expect(pdf_content).to include("User: #{user.name}")
      expect(pdf_content).to include("Test invoice description")
    end
    
    it 'includes invoice date' do
      pdf_content = invoice.generate_pdf
      
      expect(pdf_content).to include("Invoice Date:")
      expect(pdf_content).to include(invoice.created_at.strftime('%Y-%m-%d'))
    end
    
    it 'includes thank you message' do
      pdf_content = invoice.generate_pdf
      
      expect(pdf_content).to include("Thank you for your business!")
    end
  end
  
  describe '#invoice_path' do
    let(:invoice) { Invoice.create!(user: user) }
    
    it 'returns the correct path' do
      expect(invoice.invoice_path).to eq("/invoices/#{invoice.id}")
    end
  end
  
  describe '#amount' do
    context 'when amount is set' do
      let(:invoice) { Invoice.create!(user: user, amount: 199.99) }
      
      it 'returns the set amount' do
        expect(invoice.amount).to eq(199.99)
      end
    end
    
    context 'when amount is not set' do
      let(:invoice) { Invoice.new(user: user) }
      
      it 'returns default amount' do
        invoice.save!
        expect(invoice.amount).to eq(100.00)
      end
    end
  end
  
  describe '#status' do
    context 'when status is set' do
      let(:invoice) { Invoice.create!(user: user, status: 'paid') }
      
      it 'returns the set status' do
        expect(invoice.status).to eq('paid')
      end
    end
    
    context 'when status is not set' do
      let(:invoice) { Invoice.new(user: user) }
      
      it 'returns default status' do
        invoice.save!
        expect(invoice.status).to eq('pending')
      end
    end
  end
  
  describe 'notification integration' do
    let(:invoice) { Invoice.create!(user: user, amount: 150.00) }
    
    it 'creates notification when notify is called' do
      expect {
        invoice.notify :users, key: 'invoice.created'
      }.to change { user.notifications.count }.by(1)
    end
    
    it 'creates notification with correct attributes' do
      invoice.notify :users, key: 'invoice.created'
      
      notification = user.notifications.last
      expect(notification.notifiable).to eq(invoice)
      expect(notification.key).to eq('invoice.created')
    end
  end
end

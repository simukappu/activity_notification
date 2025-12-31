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
  
  describe 'edge cases and error handling' do
    context 'with missing user association' do
      let(:invoice) { Invoice.new(amount: 100.00) }
      
      it 'fails validation without user' do
        expect(invoice).not_to be_valid
      end
    end
    
    context 'with various amount values' do
      it 'handles zero amount' do
        invoice = Invoice.create!(user: user, amount: 0.0)
        expect(invoice.amount).to eq(0.0)
      end
      
      it 'handles negative amount' do
        invoice = Invoice.create!(user: user, amount: -50.0)
        expect(invoice.amount).to eq(-50.0)
      end
      
      it 'handles very large amount' do
        invoice = Invoice.create!(user: user, amount: 999999.99)
        expect(invoice.amount).to eq(999999.99)
      end
      
      it 'handles decimal precision' do
        invoice = Invoice.create!(user: user, amount: 123.456)
        pdf_content = invoice.generate_pdf
        expect(pdf_content).to include('Amount: $123.456')
      end
    end
    
    context 'with various status values' do
      it 'handles paid status' do
        invoice = Invoice.create!(user: user, status: 'paid')
        expect(invoice.status).to eq('paid')
      end
      
      it 'handles cancelled status' do
        invoice = Invoice.create!(user: user, status: 'cancelled')
        expect(invoice.status).to eq('cancelled')
      end
      
      it 'handles custom status' do
        invoice = Invoice.create!(user: user, status: 'processing')
        pdf_content = invoice.generate_pdf
        expect(pdf_content).to include('Status: processing')
      end
    end
    
    context 'with various description values' do
      it 'handles empty description' do
        invoice = Invoice.create!(user: user, description: '')
        pdf_content = invoice.generate_pdf
        expect(pdf_content).not_to include('Description: ')
      end
      
      it 'handles nil description' do
        invoice = Invoice.create!(user: user, description: nil)
        pdf_content = invoice.generate_pdf
        expect(pdf_content).not_to include('Description: ')
      end
      
      it 'handles long description' do
        long_desc = 'A' * 500
        invoice = Invoice.create!(user: user, description: long_desc)
        pdf_content = invoice.generate_pdf
        expect(pdf_content).to include("Description: #{long_desc}")
      end
      
      it 'handles description with special characters' do
        invoice = Invoice.create!(user: user, description: 'Special: $100 & 20% discount!')
        pdf_content = invoice.generate_pdf
        expect(pdf_content).to include('Special: $100 & 20% discount!')
      end
    end
    
    context 'generate_pdf with different user names' do
      it 'handles user with long name' do
        user.update!(name: 'Very Long User Name That Exceeds Normal Length')
        invoice = Invoice.create!(user: user)
        pdf_content = invoice.generate_pdf
        expect(pdf_content).to include('Very Long User Name That Exceeds Normal Length')
      end
      
      it 'handles user with special characters in name' do
        user.update!(name: "O'Brien-Smith")
        invoice = Invoice.create!(user: user)
        pdf_content = invoice.generate_pdf
        expect(pdf_content).to include("O'Brien-Smith")
      end
    end
    
    context 'PDF content formatting' do
      let(:invoice) do
        Invoice.create!(
          user: user,
          amount: 999.99,
          status: 'pending',
          description: 'Test invoice'
        )
      end
      
      it 'includes separator line' do
        pdf_content = invoice.generate_pdf
        expect(pdf_content).to include('=' * 50)
      end
      
      it 'uses newlines for formatting' do
        pdf_content = invoice.generate_pdf
        expect(pdf_content.split("\n").count).to be > 5
      end
      
      it 'includes all required fields in order' do
        pdf_content = invoice.generate_pdf
        lines = pdf_content.split("\n")
        
        # Check that invoice ID comes first
        expect(lines[0]).to include("INVOICE ##{invoice.id}")
        # Check that thank you message comes last
        expect(lines.last).to include('Thank you for your business!')
      end
    end
    
    context 'notifiable configuration' do
      let(:invoice) { Invoice.create!(user: user, amount: 200.00) }
      
      it 'returns correct notifiable_targets' do
        targets = invoice.notifiable_targets(:users, 'invoice.created')
        expect(targets).to eq([user])
      end
      
      it 'allows email notifications' do
        expect(invoice.notifiable_email_allowed?(user, 'invoice.created')).to be true
      end
      
      it 'has proper printable name' do
        expect(invoice.printable_notifiable_name).to eq("Invoice ##{invoice.id}")
      end
      
      it 'has correct notifiable path' do
        expect(invoice.notifiable_path).to eq("/invoices/#{invoice.id}")
        expect(invoice.invoice_path).to eq("/invoices/#{invoice.id}")
      end
    end
    
    context 'with different notification keys' do
      let(:invoice) { Invoice.create!(user: user, amount: 100.00) }
      
      it 'creates notification with custom key' do
        invoice.notify :users, key: 'invoice.updated'
        notification = user.notifications.last
        expect(notification.key).to eq('invoice.updated')
      end
      
      it 'creates notification with payment key' do
        invoice.notify :users, key: 'invoice.payment_received'
        notification = user.notifications.last
        expect(notification.key).to eq('invoice.payment_received')
      end
    end
  end
end

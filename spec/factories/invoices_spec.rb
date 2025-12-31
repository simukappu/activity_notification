require 'rails_helper'

describe 'Invoice Factory', type: :factory do
  describe 'invoice factory' do
    it 'creates a valid invoice' do
      invoice = build(:invoice)
      expect(invoice).to be_valid
    end
    
    it 'creates an invoice with default values' do
      invoice = build(:invoice)
      expect(invoice.amount).to eq(100.00)
      expect(invoice.status).to eq('pending')
      expect(invoice.description).to eq('Test invoice description')
    end
    
    it 'creates a persisted invoice' do
      invoice = create(:invoice)
      expect(invoice).to be_persisted
      expect(invoice.id).to be_present
    end
    
    it 'associates with a user' do
      user = create(:user)
      invoice = create(:invoice, user: user)
      expect(invoice.user).to eq(user)
    end
    
    it 'creates a user automatically if not provided' do
      invoice = create(:invoice)
      expect(invoice.user).to be_present
      expect(invoice.user).to be_a(User)
    end
    
    context 'with custom attributes' do
      it 'allows custom amount' do
        invoice = create(:invoice, amount: 250.50)
        expect(invoice.amount).to eq(250.50)
      end
      
      it 'allows custom status' do
        invoice = create(:invoice, status: 'paid')
        expect(invoice.status).to eq('paid')
      end
      
      it 'allows custom description' do
        invoice = create(:invoice, description: 'Custom description')
        expect(invoice.description).to eq('Custom description')
      end
      
      it 'allows nil description' do
        invoice = create(:invoice, description: nil)
        expect(invoice.description).to be_nil
      end
      
      it 'allows empty description' do
        invoice = create(:invoice, description: '')
        expect(invoice.description).to eq('')
      end
    end
    
    context 'creating multiple invoices' do
      it 'creates multiple distinct invoices' do
        invoices = create_list(:invoice, 3)
        expect(invoices.count).to eq(3)
        expect(invoices.map(&:id).uniq.count).to eq(3)
      end
      
      it 'creates invoices with different attributes' do
        invoices = [
          create(:invoice, amount: 100.00),
          create(:invoice, amount: 200.00),
          create(:invoice, amount: 300.00)
        ]
        
        expect(invoices[0].amount).to eq(100.00)
        expect(invoices[1].amount).to eq(200.00)
        expect(invoices[2].amount).to eq(300.00)
      end
    end
    
    context 'build vs create' do
      it 'build creates an unpersisted invoice' do
        invoice = build(:invoice)
        expect(invoice).not_to be_persisted
        expect(invoice.id).to be_nil
      end
      
      it 'build_stubbed creates a stubbed invoice' do
        invoice = build_stubbed(:invoice)
        expect(invoice.id).to be_present
        expect { invoice.save }.to raise_error
      end
    end
    
    context 'validations through factory' do
      it 'creates invoice that passes all validations' do
        invoice = create(:invoice)
        expect(invoice.valid?).to be true
      end
      
      it 'creates invoice with all required associations' do
        invoice = create(:invoice)
        expect(invoice.user).to be_present
        expect(invoice.user).to be_valid
      end
    end
    
    context 'attribute types' do
      it 'creates invoice with float amount' do
        invoice = create(:invoice, amount: 123.45)
        expect(invoice.amount).to be_a(Float)
      end
      
      it 'creates invoice with integer-like amount' do
        invoice = create(:invoice, amount: 100)
        expect(invoice.amount).to eq(100.0)
      end
      
      it 'creates invoice with string status' do
        invoice = create(:invoice, status: 'pending')
        expect(invoice.status).to be_a(String)
      end
    end
    
    context 'factory traits' do
      it 'can be extended with traits for different statuses' do
        # Testing that factory is extensible
        invoice1 = create(:invoice, status: 'pending')
        invoice2 = create(:invoice, status: 'paid')
        invoice3 = create(:invoice, status: 'cancelled')
        
        expect(invoice1.status).to eq('pending')
        expect(invoice2.status).to eq('paid')
        expect(invoice3.status).to eq('cancelled')
      end
      
      it 'can be extended with traits for different amounts' do
        small_invoice = create(:invoice, amount: 10.00)
        large_invoice = create(:invoice, amount: 10000.00)
        
        expect(small_invoice.amount).to eq(10.00)
        expect(large_invoice.amount).to eq(10000.00)
      end
    end
    
    context 'integration with notification system' do
      it 'creates invoice that can notify' do
        invoice = create(:invoice)
        expect(invoice).to respond_to(:notify)
      end
      
      it 'creates invoice that can generate PDF' do
        invoice = create(:invoice)
        expect(invoice).to respond_to(:generate_pdf)
      end
      
      it 'creates invoice with valid notifiable configuration' do
        invoice = create(:invoice)
        expect(invoice.class.ancestors).to include(ActivityNotification::Notifiable)
      end
    end
    
    context 'factory consistency' do
      it 'produces consistent results' do
        invoice1 = build(:invoice)
        invoice2 = build(:invoice)
        
        expect(invoice1.amount).to eq(invoice2.amount)
        expect(invoice1.status).to eq(invoice2.status)
        expect(invoice1.description).to eq(invoice2.description)
      end
      
      it 'allows randomization when needed' do
        invoices = create_list(:invoice, 5)
        users = invoices.map(&:user).uniq
        
        # Users should be different unless explicitly shared
        expect(users.count).to eq(5)
      end
    end
    
    context 'edge cases' do
      it 'handles zero amount' do
        invoice = create(:invoice, amount: 0.0)
        expect(invoice.amount).to eq(0.0)
      end
      
      it 'handles negative amount' do
        invoice = create(:invoice, amount: -100.0)
        expect(invoice.amount).to eq(-100.0)
      end
      
      it 'handles very large amounts' do
        invoice = create(:invoice, amount: 999999999.99)
        expect(invoice.amount).to eq(999999999.99)
      end
      
      it 'handles very small amounts' do
        invoice = create(:invoice, amount: 0.01)
        expect(invoice.amount).to eq(0.01)
      end
      
      it 'handles long descriptions' do
        long_desc = 'A' * 1000
        invoice = create(:invoice, description: long_desc)
        expect(invoice.description).to eq(long_desc)
      end
      
      it 'handles special characters in description' do
        special_desc = "Invoice with special chars: @#$%^&*()[]{}|\\/'\"<>?`~"
        invoice = create(:invoice, description: special_desc)
        expect(invoice.description).to eq(special_desc)
      end
      
      it 'handles unicode in description' do
        unicode_desc = "测试 描述 🎉 émoji ñoño"
        invoice = create(:invoice, description: unicode_desc)
        expect(invoice.description).to eq(unicode_desc)
      end
    end
    
    context 'performance' do
      it 'creates invoices efficiently' do
        start_time = Time.now
        create_list(:invoice, 10)
        duration = Time.now - start_time
        
        # Should complete reasonably quickly (adjust threshold as needed)
        expect(duration).to be < 5.0
      end
    end
    
    context 'with shared user' do
      let(:user) { create(:user) }
      
      it 'creates multiple invoices for same user' do
        invoices = create_list(:invoice, 3, user: user)
        
        expect(invoices.map(&:user).uniq.count).to eq(1)
        expect(invoices.first.user).to eq(user)
      end
      
      it 'maintains user association correctly' do
        invoice1 = create(:invoice, user: user)
        invoice2 = create(:invoice, user: user)
        
        expect(invoice1.user).to eq(invoice2.user)
        expect(user.invoices).to include(invoice1, invoice2) if user.respond_to?(:invoices)
      end
    end
  end
end

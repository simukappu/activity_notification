require 'rails_helper'

RSpec.describe Invoice, type: :model do
  let(:user) { create(:user) }
  let(:invoice) { build(:invoice, user: user) }

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_numericality_of(:amount).is_greater_than_or_equal_to(0) }
  end

  describe '#generate_pdf' do
    let(:invoice) { create(:invoice, user: user, amount: 250.00, description: 'Test invoice') }

    it 'generates PDF content with invoice details' do
      pdf_content = invoice.generate_pdf
      
      expect(pdf_content).to include("Invoice ##{invoice.id}")
      expect(pdf_content).to include("Amount: $250.0")
      expect(pdf_content).to include("Description: Test invoice")
    end

    it 'includes user information' do
      pdf_content = invoice.generate_pdf
      expect(pdf_content).to include("User: #{user.name}")
    end
  end

  describe 'acts_as_notifiable' do
    it 'can create notifications' do
      invoice = create(:invoice, user: user)
      
      expect {
        invoice.notify :users, key: 'invoice.created'
      }.to change { ActivityNotification::Notification.count }.by(1)
      
      notification = ActivityNotification::Notification.last
      expect(notification.notifiable).to eq(invoice)
      expect(notification.target).to eq(user)
      expect(notification.key).to eq('invoice.created')
    end
  end

  describe '#invoice_path' do
    it 'returns the correct path' do
      invoice = create(:invoice)
      expect(invoice.invoice_path).to eq("/invoices/#{invoice.id}")
    end
  end
end

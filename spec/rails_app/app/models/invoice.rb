module InvoiceModel
  extend ActiveSupport::Concern

  included do
    belongs_to :user
    validates :user, presence: true

    acts_as_notifiable :users,
      targets: ->(invoice, key) { [invoice.user] },
      notifiable_path: :invoice_path,
      email_allowed: true,
      printable_name: ->(invoice) { "Invoice ##{invoice.id}" }
  end

  # Method to generate PDF (example using basic text for demonstration)
  # In production, you would use a library like Prawn, WickedPDF, or CombinePDF
  def generate_pdf
    # Simple text-based PDF content for demonstration
    # In a real application, use a proper PDF library
    content = []
    content << "INVOICE ##{id}"
    content << "=" * 50
    content << ""
    content << "Invoice Date: #{created_at.strftime('%Y-%m-%d')}"
    content << "User: #{user.name}"
    content << ""
    content << "Amount: $#{amount}"
    content << "Status: #{status}"
    content << ""
    content << "Description: #{description}" if respond_to?(:description) && description.present?
    content << ""
    content << "Thank you for your business!"
    
    content.join("\n")
  end

  def invoice_path
    "/invoices/#{id}"
  end

  def amount
    # Default amount if not defined
    respond_to?(:read_attribute) && has_attribute?(:amount) ? read_attribute(:amount) : 100.00
  end

  def status
    # Default status if not defined
    respond_to?(:read_attribute) && has_attribute?(:status) ? read_attribute(:status) : 'pending'
  end
end

unless ENV['AN_TEST_DB'] == 'mongodb'
  class Invoice < ActiveRecord::Base
    include InvoiceModel
  end
else
  require 'mongoid'
  class Invoice
    include Mongoid::Document
    include Mongoid::Timestamps
    include GlobalID::Identification

    field :amount, type: Float, default: 100.00
    field :status, type: String, default: 'pending'
    field :description, type: String

    include ActivityNotification::Models
    include InvoiceModel
  end
end

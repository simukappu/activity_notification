module InvoiceModel
  extend ActiveSupport::Concern

  included do
    belongs_to :user
    
    validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :user, presence: true
    
    # Make Invoice act as a notifiable model
    acts_as_notifiable :users,
      targets: ->(invoice, key) { [invoice.user] },
      notifiable_path: :invoice_path
  end
  
  def invoice_path
    "/invoices/#{id}"
  end
  
  # Generate a simple PDF for the invoice
  def generate_pdf
    <<~PDF
      Invoice ##{id}
      User: #{user.try(:name) || 'N/A'}
      Amount: $#{amount}
      Description: #{description || 'N/A'}
      Status: #{status || 'pending'}
    PDF
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

    field :amount,      type: Float
    field :description, type: String
    field :status,      type: String

    include ActivityNotification::Models
    include InvoiceModel
  end
end

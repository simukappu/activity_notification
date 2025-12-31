class Invoice < ActiveRecord::Base
  belongs_to :user
  
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :user, presence: true
  
  # Make Invoice act as a notifiable model
  acts_as_notifiable :users,
    targets: ->(invoice, key) { [invoice.user] },
    notifiable_path: :invoice_path
  
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

class CreateInvoices < ActiveRecord::Migration[6.0]
  def change
    create_table :invoices do |t|
      t.references :user, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, default: 100.00
      t.string :status, default: 'pending'
      t.text :description

      t.timestamps
    end

    add_index :invoices, [:user_id, :created_at]
    add_index :invoices, :status
  end
end

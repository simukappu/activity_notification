class CreateInvoices < ActiveRecord::Migration[5.0]
  def change
    create_table :invoices do |t|
      t.references :user, foreign_key: true, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :status, default: 'pending'
      t.text :description

      t.timestamps
    end
    
    add_index :invoices, [:user_id, :created_at]
  end
end

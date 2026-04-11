# Migration to add notifiable polymorphic columns to subscriptions table
# for instance-level subscription support.
class <%= @migration_name %> < ActiveRecord::Migration<%= "[#{Rails.version.to_f}]" %>
  def change
    add_reference :subscriptions, :notifiable, polymorphic: true, index: true

    # Replace the old unique index with one that includes notifiable columns
    remove_index :subscriptions, [:target_type, :target_id, :key]
    add_index :subscriptions, [:target_type, :target_id, :key, :notifiable_type, :notifiable_id],
              unique: true, name: 'index_subscriptions_uniqueness',
              length: { target_type: 191, key: 191, notifiable_type: 191 }
  end
end

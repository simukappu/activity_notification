# Migration responsible for creating a table with notifications
class <%= @migration_name %> < ActiveRecord::Migration
  # Create tables
  def change
    <% if @migration_tables.include?('notifications') %>
    create_table :notifications do |t|
      t.belongs_to :target,     polymorphic: true, index: true, null: false
      t.belongs_to :notifiable, polymorphic: true, index: true, null: false
      t.string     :key,                                        null: false
      t.belongs_to :group,      polymorphic: true, index: true
      t.integer    :group_owner_id,                index: true
      t.belongs_to :notifier,   polymorphic: true, index: true
      t.text       :parameters
      t.datetime   :opened_at

      t.timestamps
    end
   <% end %>

    <% if @migration_tables.include?('subscriptions') %>
    create_table :subscriptions do |t|
      t.belongs_to :target,     polymorphic: true, index: true, null: false
      t.string     :notifiable_type,               index: true, null: false
      t.string     :key,                           index: true
      t.boolean    :enabled,                                    null: false, default: true
      t.integer    :email_enabled,                              null: false, default: true
      t.datetime   :subscribed_at
      t.datetime   :unsubscribed_at

      t.timestamps
    end
    <% end %>
  end
end

# Migration responsible for creating a table with notifications
class <%= @migration_name %> < ActiveRecord::Migration
  # Create table
  def change
    create_table :notifications do |t|
      t.belongs_to :target,     polymorphic: true, index: true, null: false
      t.belongs_to :notifiable, polymorphic: true, index: true, null: false
      t.string     :key                                       , null: false
      t.belongs_to :group,      polymorphic: true, index: true
      t.integer    :group_owner_id               , index: true
      t.belongs_to :notifier,   polymorphic: true, index: true
      t.text       :parameters
      t.datetime   :opened_at

      t.timestamps
    end
  end
end

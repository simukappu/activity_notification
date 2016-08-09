class Dummy::DummyNotifier < ActiveRecord::Base
  self.table_name = :users
  include ActivityNotification::Notifier
end

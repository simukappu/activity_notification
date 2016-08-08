class DummyNotifiable < ActiveRecord::Base
  self.table_name = :articles
  include ActivityNotification::Notifiable
end

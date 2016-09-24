class Dummy::DummyGroup < ActiveRecord::Base
  self.table_name = :articles
  include ActivityNotification::Group
end

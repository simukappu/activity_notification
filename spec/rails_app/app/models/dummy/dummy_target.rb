class Dummy::DummyTarget < ActiveRecord::Base
  self.table_name = :users
  include ActivityNotification::Target
end

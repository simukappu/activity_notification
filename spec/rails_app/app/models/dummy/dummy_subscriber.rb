class Dummy::DummySubscriber < ActiveRecord::Base
  self.table_name = :users
  acts_as_target email: 'dummy@example.com', email_allowed: true, batch_email_allowed: true, subscription_allowed: true
end

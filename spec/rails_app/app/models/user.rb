class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :confirmable
  validates :email, presence: true

  acts_as_notification_target email: :email, email_allowed: :confirmed_at
end

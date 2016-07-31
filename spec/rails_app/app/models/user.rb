class User < ActiveRecord::Base
  # devise :database_authenticatable, :registerable, :confirmable

  acts_as_notification_target email: :email, email_allowed: :confirmed_at

  validates :email, presence: true
end

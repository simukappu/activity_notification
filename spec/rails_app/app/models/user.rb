class User < ActiveRecord::Base
  # devise :database_authenticatable, :registerable, :confirmable

  include ActivityNotification::Target
  acts_as_target email: :email, email_allowed: :confirmed_at

  validates :email, presence: true
end

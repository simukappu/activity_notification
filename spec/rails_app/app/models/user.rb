class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :confirmable
  validates :email, presence: true
  has_many :articles, dependent: :delete_all
  has_many :comments, through: :articles, dependent: :delete_all

  acts_as_target email: :email, email_allowed: :confirmed_at

  def printable_name
    name
  end
end

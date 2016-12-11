class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :confirmable
  validates :email, presence: true
  has_many :articles, dependent: :destroy
  has_one :admin, dependent: :destroy

  acts_as_target email: :email, email_allowed: :confirmed_at, batch_email_allowed: :confirmed_at,
                 subscription_allowed: true, printable_name: :name
  acts_as_notifier printable_name: :name

  def admin?
    admin.present?
  end
end

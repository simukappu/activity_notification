class Admin < ActiveRecord::Base
  belongs_to :user
  validates :user, presence: true

  acts_as_notification_target email: :email,
    email_allowed: ->(admin, key) { admin.user.confirmed_at.present? },
    subscription_allowed: true,
    devise_resource: :user,
    printable_name: ->(admin) { "admin (#{admin.user.name})" }
end

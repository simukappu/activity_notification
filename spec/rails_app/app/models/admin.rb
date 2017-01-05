class Admin < ActiveRecord::Base
  belongs_to :user
  validates :user, presence: true

  acts_as_notification_target email_allowed: false,
    subscription_allowed: true,
    devise_resource: :user,
    printable_name: ->(admin) { "admin (#{admin.user.name})" }
end

unless ENV['AN_TEST_DB'] == 'mongodb'
  class Admin < ActiveRecord::Base
    belongs_to :user
    validates :user, presence: true

    acts_as_notification_target email_allowed: false,
      subscription_allowed: true,
      devise_resource: :user,
      printable_name: ->(admin) { "admin (#{admin.user.name})" }
  end
else
  require 'mongoid'
  class Admin
    include Mongoid::Document
    include Mongoid::Timestamps
    include GlobalID::Identification

    belongs_to :user
    validates :user, presence: true

    field :phone_number,   type: String
    field :slack_username, type: String

    include ActivityNotification::Models
    acts_as_notification_target email_allowed: false,
      subscription_allowed: true,
      devise_resource: :user,
      printable_name: ->(admin) { "admin (#{admin.user.name})" }
  end
end

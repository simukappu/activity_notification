module ActivityNotification
  module Notifier
    extend ActiveSupport::Concern
    included do
      include Common
      has_many :sent_notifications,
        class_name: "::ActivityNotification::Notification",
        as: :notifier
    end
  end
end
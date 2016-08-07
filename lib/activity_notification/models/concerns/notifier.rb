module ActivityNotification
  module Notifier
    extend ActiveSupport::Concern
    included do
      include Common
      has_many :sent_notifications,
        class_name: "::ActivityNotification::Notification",
        as: :notifier
    end

    class_methods do
      def available_as_notifier?
        true
      end
    end
  end
end
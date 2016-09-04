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
      # Checks if the model includes notifier and notifier methods are available.
      # @return [Boolean] Always true
      def available_as_notifier?
        true
      end
    end
  end
end
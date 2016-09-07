module ActivityNotification
  # Manages to add all required configurations to notifier models of notification.
  module ActsAsNotifier
    extend ActiveSupport::Concern

    class_methods do
      # Adds required configurations to notifier models.
      # @return [nil] nil
      def acts_as_notifier
        include Notifier
      end
    end
  end
end

module ActivityNotification
  module ActsAsNotifier
    extend ActiveSupport::Concern

    class_methods do
      def acts_as_notifier
        include Notifier
        true
      end
    end
  end
end

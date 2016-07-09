module ActivityNotification
  class << self
    # Setter for remembering controller instance
    def set_controller(controller)
      Thread.current[:activity_notification_controller] = controller
    end

    # Getter for accessing the controller instance
    def get_controller
      Thread.current[:activity_notification_controller]
    end
  end

  # Module included in controllers to allow p_a access to controller instance
  module StoreController
    extend ActiveSupport::Concern

    included do
      around_action :store_controller_for_activity_notification if     respond_to?(:around_action)
      around_filter :store_controller_for_activity_notification unless respond_to?(:around_action)
    end

    def store_controller_for_activity_notification
      ActivityNotification.set_controller(self)
      yield
    ensure
      ActivityNotification.set_controller(nil)
    end
  end
end

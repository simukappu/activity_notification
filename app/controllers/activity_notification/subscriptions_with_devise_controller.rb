module ActivityNotification
  # Controller to manage subscriptions with Devise authentication.
  class SubscriptionsWithDeviseController < SubscriptionsController
    include DeviceAuthenticationController
  end
end

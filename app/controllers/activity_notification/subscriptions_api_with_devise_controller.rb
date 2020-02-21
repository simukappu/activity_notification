module ActivityNotification
  # Controller to manage subscriptions API with Devise authentication.
  class SubscriptionsApiWithDeviseController < SubscriptionsApiController
    if ActivityNotification.config.action_cable_with_devise
      include DeviseTokenAuth::Concerns::SetUserByToken
      include DeviseAuthenticationController
    end
  end
end
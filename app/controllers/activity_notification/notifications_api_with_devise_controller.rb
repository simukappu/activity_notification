module ActivityNotification
  # Controller to manage notifications API with Devise authentication.
  class NotificationsApiWithDeviseController < NotificationsApiController
    if ActivityNotification.config.action_cable_with_devise
      include DeviseTokenAuth::Concerns::SetUserByToken
      include DeviseAuthenticationController
    end
  end
end
module ActivityNotification
  # Controller to manage notifications API with Devise authentication.
  class NotificationsApiWithDeviseController < NotificationsApiController
    include DeviseTokenAuth::Concerns::SetUserByToken
    include DeviseAuthenticationController
  end
end
module ActivityNotification
  module Models
    extend ActiveSupport::Concern
    included do
      include ActivityNotification::ActsAsTarget
      include ActivityNotification::ActsAsNotifiable
      include ActivityNotification::ActsAsNotifier
    end
  end
end

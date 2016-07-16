FactoryGirl.define do
  factory :notification, class: ActivityNotification::Notification do
    association :target, factory: :user
    association :notifiable, factory: :article
    key "default.default"
  end
end

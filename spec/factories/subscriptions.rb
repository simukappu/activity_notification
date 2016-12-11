FactoryGirl.define do
  factory :subscription, class: ActivityNotification::Subscription do
    association :target, factory: :confirmed_user
    key "default.default"
    subscribed_at DateTime.now
    subscribed_to_email_at DateTime.now
  end
end

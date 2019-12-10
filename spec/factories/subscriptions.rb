FactoryBot.define do
  factory :subscription, class: ActivityNotification::Subscription do
    association :target, factory: :confirmed_user
    key { "default.default.#{Time.current.to_i}" }
    subscribed_at { Time.current }
    subscribed_to_email_at { Time.current }
  end
end

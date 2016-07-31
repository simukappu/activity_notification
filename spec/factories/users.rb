FactoryGirl.define do
  factory :user do
    email ['a'..'z'].shuffle.join + '@example.com'
  end
end

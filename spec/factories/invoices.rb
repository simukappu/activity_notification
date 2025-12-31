FactoryBot.define do
  factory :invoice do
    association :user
    amount { 100.00 }
    status { 'pending' }
    description { 'Test invoice description' }
  end
end

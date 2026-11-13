Dynamoid.configure do |config|
  config.namespace = ENV['AN_NO_DYNAMODB_NAMESPACE'] ? "" : "activity_notification_#{Rails.env}"
  # Use on-demand capacity mode since provisioned throughput can throttle the tests on DynamoDB and AWS Emulator
  config.capacity_mode = :on_demand
  unless Rails.env.production?
    config.endpoint = 'http://localhost:8000'
  end
  unless Rails.env.test?
    config.store_datetime_as_string = true
  end
end

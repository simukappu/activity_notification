module ActivityNotification
  module Swagger::SubscriptionSchema #:nodoc:
    extend ActiveSupport::Concern
    include ::Swagger::Blocks
  
    included do
      swagger_component do
        schema :SubscriptionAttributes do
          key :type, :object
          property :key do
            key :type, :string
            key :example, "comment.default"
          end
          property :subscribing do
            key :type, :boolean
            key :default, true
            key :example, true
          end
          property :subscribing_to_email do
            key :type, :boolean
            key :default, true
            key :example, true
          end
        end
    
        schema :Subscription do
          key :type, :object
          key :required, [ :id, :target_type, :target_id, :key, :subscribing, :subscribing_to_email, :created_at, :updated_at, :target ]
          allOf do
            schema do
              key :type, :object
              property :id do
                key :oneOf, [
                  { type: :integer },
                  { type: :string }
                ]
                key :description, "This parameter type is integer with ActiveRecord, but will be string with Mongoid or Dynamoid ORMs."
                key :example, 321
              end
              property :target_type do
                key :type, :string
                key :example, "User"
              end
              property :target_id do
                key :oneOf, [
                  { type: :integer },
                  { type: :string }
                ]
                key :description, "This parameter type is integer with ActiveRecord, but will be string with Mongoid or Dynamoid ORMs."
                key :example, 1
              end
            end
            schema do
              key :'$ref', :SubscriptionAttributes
            end
            schema do
              key :type, :object
              property :subscribed_at do
                key :type, :string
                key :format, :'date-time'
                key :nullable, true
              end
              property :unsubscribed_at do
                key :type, :string
                key :format, :'date-time'
                key :nullable, true
              end
              property :subscribed_to_email_at do
                key :type, :string
                key :format, :'date-time'
                key :nullable, true
              end
              property :unsubscribed_to_email_at do
                key :type, :string
                key :format, :'date-time'
                key :nullable, true
              end
              property :optional_targets do
                key :type, :object
                key :additionalProperties, {
                  type: "object",
                  properties: {
                    subscribing_to_optional_target_name: {
                      type: "boolean"
                    },
                    subscribed_to_optional_target_name_at: {
                      type: "string",
                      format: "date-time"
                    }
                  }
                }
                key :example, {
                  "subscribing_to_slack": true,
                  "subscribed_to_slack_at": Time.current
                }
              end
              property :created_at do
                key :type, :string
                key :format, :'date-time'
              end
              property :updated_at do
                key :type, :string
                key :format, :'date-time'
              end
              property :target do
                key :type, :object
                key :description, "Associated target model in your application"
                key :example, {
                  "id": 1,
                  "email": "ichiro@example.com",
                  "name": "Ichiro",
                  "created_at": Time.current,
                  "updated_at": Time.current
                }
              end
            end
          end
        end

        schema :SubscriptionInput do
          key :type, :object
          key :required, [ :key ]
          allOf do
            schema do
              key :'$ref', :SubscriptionAttributes
            end
            schema do
              key :type, :object
              property :optional_targets do
                key :type, :object
                key :additionalProperties, {
                  type: "object",
                  properties: {
                    subscribing_to_optional_target_name: {
                      type: "boolean"
                    }
                  }
                }
                key :example, {
                  "subscribing_to_slack": true
                }
              end
            end
          end
        end
      end
    end
  end
end

module ActivityNotification
  module PolymorphicHelpers
    extend ActiveSupport::Concern

    included do
      class ::String
        def to_model_name
          singularize.camelize
        end
      
        def to_model_class
          to_model_name.classify.constantize
        end
      
        def to_resource_name
          singularize.underscore
        end
      
        def to_resources_name
          pluralize.underscore
        end

        def to_boolean(default = nil)
          return true if ['true', '1', 'yes', 'on', 't'].include? self
          return false if ['false', '0', 'no', 'off', 'f'].include? self
          return default
        end
      end
    end

  end
end

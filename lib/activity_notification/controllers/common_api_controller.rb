module ActivityNotification
  # Module included in api controllers to select target
  module CommonApiController
    extend ActiveSupport::Concern

    included do
      rescue_from ActiveRecord::RecordNotFound,      with: :render_resource_not_found if defined?(ActiveRecord)
      rescue_from Mongoid::Errors::DocumentNotFound, with: :render_resource_not_found if ActivityNotification.config.orm == :mongoid
      rescue_from Dynamoid::Errors::RecordNotFound,  with: :render_resource_not_found if ActivityNotification.config.orm == :dynamoid
    end

    protected

      # Override to do nothing instead of JavaScript view for ajax request or redirects to back.
      # @api protected
      def return_back_or_ajax
      end

      # Override to do nothing instead of redirecting to notifiable_path
      # @api protected
      def redirect_to_notifiable_path
      end

      # Override to do nothing instead of redirecting to subscription path
      # @api protected
      def redirect_to_subscription_path
      end

      # Returns methods to add polymorphic association type and id to JSON of the model.
      # Dynamoid models store polymorphic associations as composite keys (e.g. target_key),
      # so their type and id are added to JSON responses as with other ORMs.
      # @api protected
      # @param [Class] model_class Model class of the JSON (e.g. ActivityNotification::Notification)
      # @return [Array<Symbol>] Methods to add to JSON
      def polymorphic_association_json_methods(model_class)
        associations = ActivityNotification.config.orm == :dynamoid ? model_class._associated_composite_records : []
        associations.flat_map { |association| [:"#{association}_type", :"#{association}_id"] }
      end

  end
end

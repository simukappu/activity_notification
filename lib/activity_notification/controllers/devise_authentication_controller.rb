module ActivityNotification
  # Module included in controllers to authenticate with Devise module
  module DeviseAuthenticationController
    extend ActiveSupport::Concern

    included do
      prepend_before_action :authenticate_devise_resource!
      before_action :authenticate_target!
    end

    protected

      # Authenticate devise resource by Devise (e.g. calling authenticate_user! method).
      # @api protected
      # @todo Needs to call authenticate method by more secure way
      # @return [Responce] Redirects for unsigned in target by Devise, returns HTTP 403 without neccesary target method or returns 400 when request parameters are not enough
      def authenticate_devise_resource!
        if params[:devise_type].present?
          authenticate_method_name = "authenticate_#{params[:devise_type].to_resource_name}!"
          if respond_to?(authenticate_method_name)
            send(authenticate_method_name)
          else
            render plain: "403 Forbidden: Unauthenticated", status: 403
          end
        else
          render plain: "400 Bad Request: Missing parameter", status: 400
        end
      end

      # Authenticate the target of requested notification with authenticated devise resource.
      # @api protected
      # @todo Needs to call authenticate method by more secure way
      # @return [Responce] Returns HTTP 403 for unauthorized target
      def authenticate_target!
        current_resource_method_name = "current_#{params[:devise_type].to_resource_name}"
        unless @target.authenticated_with_devise?(send(current_resource_method_name))
          render plain: "403 Forbidden: Unauthorized target", status: 403
        end
      end
  end
end

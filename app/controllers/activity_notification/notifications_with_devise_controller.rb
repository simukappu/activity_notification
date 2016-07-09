module ActivityNotification
  class NotificationsWithDeviseController < NotificationsController
    prepend_before_action :authenticate_devise_resource!
    before_action :authenticate_target!
    
    protected

      def authenticate_devise_resource!
        authenticate_method_name = "authenticate_#{params[:devise_type].to_resource_name}!"
        if respond_to?(authenticate_method_name)
          send(authenticate_method_name)
        else
          render text: "403 Forbidden: Unauthenticated", status: 403
        end
      end

      def authenticate_target!
        current_resource_method_name = "current_#{params[:devise_type].to_resource_name}"
        if respond_to?(current_resource_method_name)
          unless @target.authenticate_with_devise?(send(current_resource_method_name))
            render text: "403 Forbidden: Unauthorized target", status: 403
          end
        else
          render text: "403 Forbidden: Unauthenticated", status: 403
        end
      end

  end
end

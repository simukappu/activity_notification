module ActivityNotification
  class NotificationsController < ActivityNotification.config.parent_controller.constantize
    # Include StoreController to allow ActivityNotification access to controller instance
    include ActivityNotification::StoreController
    # Include PolymorphicHelpers to resolve string extentions
    include ActivityNotification::PolymorphicHelpers
    prepend_before_action :set_target
    before_action :set_notification, except: [:index, :open_all]
    before_action :set_view_prefixes, except: [:move]
  
    DEFAULT_VIEW_DIRECTORY = "default"
  
    # GET /:target_type/:target_id/notifcations
    def index
      @notifications = load_notification_index(params[:filter], params[:limit]) if params[:reload].to_s.to_boolean(true)
      respond_to do |format|
        format.html # index.html.erb
        format.json { render json: @notifications.to_json(include: [:target, :notifiable, :group]) }
      end
    end

    # POST /:target_type/:target_id/notifcations/open_all
    def open_all
      @target.open_all_notifications
      return_back_or_ajax(params[:filter], params[:limit])
    end
  
    # GET /:target_type/:target_id/notifcations/:id
    def show
    end
  
    # DELETE /:target_type/:target_id/notifcations/:id
    def destroy
      @notification.destroy
      return_back_or_ajax(params[:filter], params[:limit])
    end
  
    # POST /:target_type/:target_id/notifcations/:id/open
    def open
      @notification.open!
      params[:move].to_s.to_boolean(false) ? 
        move : 
        return_back_or_ajax(params[:filter], params[:limit])
    end

    # GET /:target_type/:target_id/notifcations/:id/move
    def move
      @notification.open! if params[:open].to_s.to_boolean(false)
      redirect_to @notification.notifiable_path
    end
  
    # No action routing
    # This method is called from target_view_path method
    # This method can be overriden
    def controller_path
      "activity_notification/notifications"
    end

    # No action routing
    # This method needs to be public since it is called from view helper
    def target_view_path
      target_type = @target.to_resources_name
      view_path = [controller_path, target_type].join('/')
      lookup_context.exists?(action_name, view_path) ?
        view_path :
        [controller_path, DEFAULT_VIEW_DIRECTORY].join('/')
    end

    protected

      def set_target
        if (target_type = params[:target_type]).present?
          target_class = target_type.to_model_class
          @target = params[:target_id].present? ?
            target_class.find_by_id!(params[:target_id]) : 
            target_class.find_by_id!(params["#{target_type.to_resource_name}_id"])
        else
          render plain: "400 Bad Request: Missing parameter", status: 400
        end
      end
  
      def set_notification
        @notification = Notification.find_by_id!(params[:id])
        if @target.present? and @notification.target != @target
          render plain: "403 Forbidden: Wrong target", status: 403
        end
      end

      def load_notification_index(filter, limit)
        limit = nil unless limit.to_i > 0
        case filter
        when 'opened'
          @target.opened_notification_index_with_attributes(limit)
        when 'unopened'
          @target.unopened_notification_index_with_attributes(limit)
        else
          @target.notification_index_with_attributes(limit)
        end
      end

      def set_view_prefixes
        lookup_context.prefixes.prepend(target_view_path)
      end
  
      def return_back_or_ajax(filter, limit)
        @notifications = load_notification_index(params[:filter], params[:limit]) if params[:reload].to_s.to_boolean(true)
        respond_to do |format|
          if request.xhr?
            format.js
          # :skip-rails4:
          elsif Rails::VERSION::MAJOR >= 5
            redirect_back fallback_location: { action: :index }, filter: filter, limit: limit and return
          # :skip-rails4:
          # :skip-rails5:
          elsif request.referer
            redirect_to :back, filter: filter, limit: limit and return
          else
            redirect_to action: :index, filter: filter, limit: limit and return
          end
          # :skip-rails5:
        end
      end

  end
end
module ActivityNotification
  class NotificationsController < ActivityNotification.config.parent_controller.constantize
    include ActivityNotification::StoreController
    include ActivityNotification::PolymorphicHelpers
    prepend_before_action :set_target
    before_action :set_notification, except: [:index, :open_all]
    before_action :set_view_prefixes, except: [:move]
  
    DEFAULT_VIEW_DIRECTORY = "default"
  
    # GET /:target_type/:target_id/notifcations
    def index
      @notifications = load_notifications_index(params[:filter], params[:limit]) if params[:reload].to_s.to_boolean(true)
      respond_to do |format|
        format.html # index.html.erb
        format.json { render json: @notifications.to_json(include: [:target, :notifiable, :group]) }
      end
    end

    # POST /:target_type/:target_id/notifcations/open_all
    def open_all
      @target.open_all_notifications
      @notifications = load_notifications_index(params[:filter], params[:limit]) if params[:reload].to_s.to_boolean(true)
      return_back_or_ajax(params[:filter], params[:limit])
    end
  
    # GET /:target_type/:target_id/notifcations/:id
    def show
    end
  
    # DELETE /:target_type/:target_id/notifcations/:id
    def destroy
      @notification.destroy
      @notifications = load_notifications_index(params[:filter], params[:limit]) if params[:reload].to_s.to_boolean(true)
      return_back_or_ajax(params[:filter], params[:limit])
    end
  
    # POST /:target_type/:target_id/notifcations/:id/open
    def open
      @notification.open!
      @notifications = load_notifications_index(params[:filter], params[:limit]) if params[:reload].to_s.to_boolean(true)
      params[:move].to_s.to_boolean(false) ? 
        move : 
        return_back_or_ajax(params[:filter], params[:limit])
    end

    # GET /:target_type/:target_id/notifcations/:id/move
    def move
      @notification.open! if params[:open].to_s.to_boolean(false)
      redirect_to @notification.notifiale_path
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
          render text: "400 Bad Request: Missing parameter", status: 400
        end
      end
  
      def set_notification
        @notification = Notification.find_by_id!(params[:id])
        if @target.present? and @notification.target != @target
          render text: "403 Forbidden: Wrong target", status: 403
        end
      end

      def load_notifications_index(filter, limit)
        limit = nil unless limit.to_i > 0
        case filter
        when 'opened'
          @target.opened_notifications_index_with_attributes(limit)
        when 'unopened'
          @target.unopened_notifications_index_with_attributes(limit)
        else
          @target.notifications_index_with_attributes(limit)
        end
      end

      def set_view_prefixes
        lookup_context.prefixes.prepend(target_view_path)
      end
  
      def return_back_or_ajax(filter, limit)
        respond_to do |format|
          if request.xhr?
            format.js
          elsif request.referer
            redirect_to :back, filter: filter, limit: limit and return
          else
            redirect_to action: :index, filter: filter, limit: limit and return
          end
        end
      end

  end
end
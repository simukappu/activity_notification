module ActivityNotification
  # Controller to manage notifications.
  class NotificationsController < ActivityNotification.config.parent_controller.constantize
    # Include StoreController to allow ActivityNotification access to controller instance
    include ActivityNotification::StoreController
    # Include PolymorphicHelpers to resolve string extentions
    include ActivityNotification::PolymorphicHelpers
    prepend_before_action :set_target
    before_action :set_notification, except: [:index, :open_all]
    before_action :set_view_prefixes, except: [:move]
  
    DEFAULT_VIEW_DIRECTORY = "default"
  
    # Shows notification index of the target.
    #
    # GET /:target_type/:target_id/notifcations
    # @overload index(params)
    #   @param [Hash] params Request parameters
    #   @option params [String] :filter  (nil)     Filter option to load notification index. Nothing means auto loading. 'opened' means opened only and 'unopened' means unopened only.
    #   @option params [String] :limit   (nil)     Limit to query for notifications
    #   @option params [String] :reload  ('true')  Whether notification index will be reloaded
    #   @return [Responce] HTML view as default or JSON of notification index with json format parameter
    def index
      @notifications = load_notification_index(params) if params[:reload].to_s.to_boolean(true)
      respond_to do |format|
        format.html # index.html.erb
        format.json { render json: @notifications.to_json(include: [:target, :notifiable, :group]) }
      end
    end

    # Opens all notifications of the target.
    #
    # POST /:target_type/:target_id/notifcations/open_all
    # @overload open_all(params)
    #   @param [Hash] params Request parameters
    #   @option params [String] :filter  (nil)     Filter option to load notification index (Nothing as auto, 'opened' or 'unopened')
    #   @option params [String] :limit   (nil)     Limit to query for notifications
    #   @option params [String] :reload  ('true')  Whether notification index will be reloaded
    #   @option params [String] :filtered_by_type       (nil) Notifiable type for filter
    #   @option params [String] :filtered_by_group_type (nil) Group type for filter, valid only :filtered_by_group_id
    #   @option params [String] :filtered_by_group_id   (nil) Group instance id for filter, valid only :filtered_by_group_type
    #   @option params [String] :filtered_by_key        (nil) Key of the notification for filter 
    #   @return [Responce] JavaScript view for ajax request or redirects to back as default
    def open_all
      @target.open_all_notifications(params)
      return_back_or_ajax(params[:filter], params[:limit])
    end
  
    # Shows a notification.
    #
    # GET /:target_type/:target_id/notifcations/:id
    # @overload show(params)
    #   @param [Hash] params Request parameters
    #   @return [Responce] HTML view as default
    def show
    end
  
    # Deletes a notification.
    #
    # DELETE /:target_type/:target_id/notifcations/:id
    #
    # @overload destroy(params)
    #   @param [Hash] params Request parameters
    #   @option params [String] :filter  (nil)     Filter option to load notification index (Nothing as auto, 'opened' or 'unopened')
    #   @option params [String] :limit   (nil)     Limit to query for notifications
    #   @option params [String] :reload  ('true')  Whether notification index will be reloaded
    #   @return [Responce] JavaScript view for ajax request or redirects to back as default
    def destroy
      @notification.destroy
      return_back_or_ajax(params[:filter], params[:limit])
    end
  
    # Opens a notification.
    #
    # POST /:target_type/:target_id/notifcations/:id/open
    # @overload open(params)
    #   @param [Hash] params Request parameters
    #   @option params [String] :move    ('false') Whether redirects to notifiable_path after the notification is opened
    #   @option params [String] :filter  (nil)     Filter option to load notification index (Nothing as auto, 'opened' or 'unopened')
    #   @option params [String] :limit   (nil)     Limit to query for notifications
    #   @option params [String] :reload  ('true')  Whether notification index will be reloaded
    #   @return [Responce] JavaScript view for ajax request or redirects to back as default
    def open
      @notification.open!
      params[:move].to_s.to_boolean(false) ? 
        move : 
        return_back_or_ajax(params[:filter], params[:limit])
    end

    # Moves to notifiable_path of the notification.
    #
    # GET /:target_type/:target_id/notifcations/:id/move
    # @overload open(params)
    #   @param [Hash] params Request parameters
    #   @option params [String] :open    ('false') Whether the notification will be opened
    #   @option params [String] :filter  (nil)     Filter option to load notification index (Nothing as auto, 'opened' or 'unopened')
    #   @option params [String] :limit   (nil)     Limit to query for notifications
    #   @option params [String] :reload  ('true')  Whether notification index will be reloaded
    #   @return [Responce] JavaScript view for ajax request or redirects to back as default
    def move
      @notification.open! if params[:open].to_s.to_boolean(false)
      redirect_to @notification.notifiable_path
    end
  
    # Returns controller path.
    # This method has no action routing and is called from target_view_path method.
    # This method can be overriden.
    # @return [String] "activity_notification/notifications" as controller path
    def controller_path
      "activity_notification/notifications"
    end

    # Returns path of the target view templates.
    # This method has no action routing and needs to be public since it is called from view helper.
    def target_view_path
      target_type = @target.to_resources_name
      view_path = [controller_path, target_type].join('/')
      lookup_context.exists?(action_name, view_path) ?
        view_path :
        [controller_path, DEFAULT_VIEW_DIRECTORY].join('/')
    end

    protected

      # Sets @target instance variable from request parameters.
      # @api protected
      # @return [Object] Target instance (Returns HTTP 400 when request parameters are not enough)
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
  
      # Sets @notification instance variable from request parameters.
      # @api protected
      # @return [Object] Notification instance (Returns HTTP 403 when the target of notification is different from specified target by request parameter)
      def set_notification
        @notification = Notification.find_by_id!(params[:id])
        if @target.present? and @notification.target != @target
          render plain: "403 Forbidden: Wrong target", status: 403
        end
      end

      # Loads notification index with request parameters.
      # @api protected
      # @param [Hash] params Request parameter options for notification index
      # @option params [String]  :filter                 (nil)   Filter option to load notification index (Nothing as auto, 'opened' or 'unopened')
      # @option params [Integer] :limit                  (nil)   Limit to query for notifications
      # @option params [Boolean] :reverse                (false) If notification index will be ordered as earliest first
      # @option params [String]  :filtered_by_type       (nil)   Notifiable type for filter
      # @option params [String]  :filtered_by_group_type (nil)   Group type for filter, valid with :filtered_by_group_id
      # @option params [String]  :filtered_by_group_id   (nil)   Group instance id for filter, valid with :filtered_by_group_type
      # @option params [String]  :filtered_by_key        (nil)   Key of the notification for filter
      # @return [Array] Array of notification index
      def load_notification_index(params = {})
        limit   = params[:limit].to_i > 0 ? params[:limit].to_i : nil
        reverse = params[:reverse].to_s.to_boolean(false)
        options = params.slice(:filtered_by_type, :filtered_by_group_type, :filtered_by_group_id, :filtered_by_key )
                        .merge(limit: limit, reverse: reverse)
        case params[:filter]
        when 'opened'
          @target.opened_notification_index_with_attributes(options)
        when 'unopened'
          @target.unopened_notification_index_with_attributes(options)
        else
          @target.notification_index_with_attributes(options)
        end
      end

      # Sets view prefixes for target view path.
      # @api protected
      def set_view_prefixes
        lookup_context.prefixes.prepend(target_view_path)
      end
  
      # Returns JavaScript view for ajax request or redirects to back as default.
      # @api protected
      # @param [String] filter Filter option to load notification index (Nothing as auto, 'opened' or 'unopened')
      # @param [String] limit Limit to query for notifications
      # @return [Responce] JavaScript view for ajax request or redirects to back as default
      def return_back_or_ajax(filter, limit)
        @notifications = load_notification_index(params) if params[:reload].to_s.to_boolean(true)
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
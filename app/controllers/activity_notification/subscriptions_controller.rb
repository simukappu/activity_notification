module ActivityNotification
  # Controller to manage subscriptions.
  class SubscriptionsController < ActivityNotification.config.parent_controller.constantize
    # Include StoreController to allow ActivityNotification access to controller instance
    include ActivityNotification::StoreController
    # Include PolymorphicHelpers to resolve string extentions
    include ActivityNotification::PolymorphicHelpers
    prepend_before_action :set_target
    before_action :set_subscription, except: [:index, :create]
    before_action :set_view_prefixes
  
    DEFAULT_VIEW_DIRECTORY = "default"
  
    # Shows subscription index of the target.
    #
    # GET /:target_type/:target_id/subscriptions
    # @overload index(params)
    #   @param [Hash] params Request parameter options for subscription index
    #   @option params [String] :filter          (nil)     Filter option to load subscription index (Nothing as all, 'configured' or 'unconfigured')
    #   @option params [String] :limit           (nil)     Limit to query for subscriptions
    #   @option params [String] :reverse         ('false') If subscription index and unconfigured notification keys will be ordered as earliest first
    #   @option params [String] :filtered_by_key (nil)     Key of the subscription for filter
    #   @return [Responce] HTML view as default or JSON of subscription index with json format parameter
    def index
      set_index_options
      load_subscription_index(@index_options) if params[:reload].to_s.to_boolean(true)
      respond_to do |format|
        format.html # index.html.erb
        format.json { render json: { subscriptions: @subscriptions, unconfigured_notification_keys: @notification_keys } }
      end
    end

    # Creates a subscription.
    #
    # POST /:target_type/:target_id/subscriptions
    #
    # @overload create(params)
    #   @param [Hash] params Request parameters
    #   @option params [String] :subscription                              Subscription parameters
    #   @option params [String] :subscription[:key]                        Key of the subscription
    #   @option params [String] :subscription[:subscribing]          (nil) If the target will subscribe to the notification
    #   @option params [String] :subscription[:subscribing_to_email] (nil) If the target will subscribe to the notification email
    #   @option params [String] :filter          (nil)     Filter option to load subscription index (Nothing as all, 'configured' or 'unconfigured')
    #   @option params [String] :limit           (nil)     Limit to query for subscriptions
    #   @option params [String] :reverse         ('false') If subscription index and unconfigured notification keys will be ordered as earliest first
    #   @option params [String] :filtered_by_key (nil)     Key of the subscription for filter
    #   @return [Responce] JavaScript view for ajax request or redirects to back as default
    def create
      @target.create_subscription(subscription_params)
      return_back_or_ajax
    end

    # Shows a subscription.
    #
    # GET /:target_type/:target_id/subscriptions/:id
    # @overload show(params)
    #   @param [Hash] params Request parameters
    #   @return [Responce] HTML view as default
    def show
    end
  
    # Deletes a subscription.
    #
    # DELETE /:target_type/:target_id/subscriptions/:id
    #
    # @overload destroy(params)
    #   @param [Hash] params Request parameters
    #   @option params [String] :filter          (nil)     Filter option to load subscription index (Nothing as all, 'configured' or 'unconfigured')
    #   @option params [String] :limit           (nil)     Limit to query for subscriptions
    #   @option params [String] :reverse         ('false') If subscription index and unconfigured notification keys will be ordered as earliest first
    #   @option params [String] :filtered_by_key (nil)     Key of the subscription for filter
    #   @return [Responce] JavaScript view for ajax request or redirects to back as default
    def destroy
      @subscription.destroy
      return_back_or_ajax
    end

    # Subscribes to the notification.
    #
    # POST /:target_type/:target_id/subscriptions/:id/subscribe
    # @overload open(params)
    #   @param [Hash] params Request parameters
    #   @option params [String] :filter          (nil)     Filter option to load subscription index (Nothing as all, 'configured' or 'unconfigured')
    #   @option params [String] :limit           (nil)     Limit to query for subscriptions
    #   @option params [String] :reverse         ('false') If subscription index and unconfigured notification keys will be ordered as earliest first
    #   @option params [String] :filtered_by_key (nil)     Key of the subscription for filter
    #   @return [Responce] JavaScript view for ajax request or redirects to back as default
    def subscribe
      @subscription.subscribe
      return_back_or_ajax
    end

    # Unsubscribes to the notification.
    #
    # POST /:target_type/:target_id/subscriptions/:id/unsubscribe
    # @overload open(params)
    #   @param [Hash] params Request parameters
    #   @option params [String] :filter          (nil)     Filter option to load subscription index (Nothing as all, 'configured' or 'unconfigured')
    #   @option params [String] :limit           (nil)     Limit to query for subscriptions
    #   @option params [String] :reverse         ('false') If subscription index and unconfigured notification keys will be ordered as earliest first
    #   @option params [String] :filtered_by_key (nil)     Key of the subscription for filter
    #   @return [Responce] JavaScript view for ajax request or redirects to back as default
    def unsubscribe
      @subscription.unsubscribe
      return_back_or_ajax
    end

    # Subscribes to the notification email.
    #
    # POST /:target_type/:target_id/subscriptions/:id/subscribe_email
    # @overload open(params)
    #   @param [Hash] params Request parameters
    #   @option params [String] :filter          (nil)     Filter option to load subscription index (Nothing as all, 'configured' or 'unconfigured')
    #   @option params [String] :limit           (nil)     Limit to query for subscriptions
    #   @option params [String] :reverse         ('false') If subscription index and unconfigured notification keys will be ordered as earliest first
    #   @option params [String] :filtered_by_key (nil)     Key of the subscription for filter
    #   @return [Responce] JavaScript view for ajax request or redirects to back as default
    def subscribe_to_email
      @subscription.subscribe_to_email
      return_back_or_ajax
    end

    # Unsubscribes to the notification email.
    #
    # POST /:target_type/:target_id/subscriptions/:id/unsubscribe_email
    # @overload open(params)
    #   @param [Hash] params Request parameters
    #   @option params [String] :filter          (nil)     Filter option to load subscription index (Nothing as all, 'configured' or 'unconfigured')
    #   @option params [String] :limit           (nil)     Limit to query for subscriptions
    #   @option params [String] :reverse         ('false') If subscription index and unconfigured notification keys will be ordered as earliest first
    #   @option params [String] :filtered_by_key (nil)     Key of the subscription for filter
    #   @return [Responce] JavaScript view for ajax request or redirects to back as default
    def unsubscribe_to_email
      @subscription.unsubscribe_to_email
      return_back_or_ajax
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

      # Sets @subscription instance variable from request parameters.
      # @api protected
      # @return [Object] Subscription instance (Returns HTTP 403 when the target of subscription is different from specified target by request parameter)
      def set_subscription
        @subscription = Subscription.includes(:target).find_by_id!(params[:id])
        if @target.present? and @subscription.target != @target
          render plain: "403 Forbidden: Wrong target", status: 403
        end
      end

      # Only allow a trusted parameter "white list" through.
      def subscription_params
        params.require(:subscription).permit(:key, :subscribing, :subscribing_to_email)
      end

      # Sets options to load subscription index from request parameters.
      # @api protected
      # @return [Hash] options to load subscription index
      def set_index_options
        limit          = params[:limit].to_i > 0 ? params[:limit].to_i : nil
        reverse        = params[:reverse].present? ?
                           params[:reverse].to_s.to_boolean(false) : nil
        @index_options = params.permit(:filter, :filtered_by_key)
                               .to_h.symbolize_keys.merge(limit: limit, reverse: reverse)
      end

      # Loads subscription index with request parameters.
      # @api protected
      # @param [Hash] params Request parameter options for subscription index
      # @option params [Symbol|String] :filter          (nil) Filter option to load subscription index (Nothing as all, 'configured' or 'unconfigured')
      # @option params [Integer]       :limit           (nil) Limit to query for subscriptions
      # @option params [String]        :filtered_by_key (nil) Key of the subscription for filter
      # @return [Array] Array of subscription index
      def load_subscription_index(options = {})
        case options[:filter]
        when :configured, 'configured'
          @subscriptions = @target.subscription_index(options.merge(with_target: true))
          @notification_keys = nil
        when :unconfigured, 'unconfigured'
          @subscriptions = nil
          @notification_keys = @target.notification_keys(options.merge(filter: :unconfigured))
        else
          @subscriptions = @target.subscription_index(options.merge(with_target: true))
          @notification_keys = @target.notification_keys(options.merge(filter: :unconfigured))
        end
      end

      # Returns controller path.
      # This method is called from target_view_path method and can be overriden.
      # @api protected
      # @return [String] "activity_notification/subscriptions" as controller path
      def controller_path
        "activity_notification/subscriptions"
      end

      # Returns path of the target view templates.
      # Do not make this method public since Rendarable module calls controller's target_view_path method to render notifications.
      # @api protected
      def target_view_path
        target_type = @target.to_resources_name
        view_path = [controller_path, target_type].join('/')
        lookup_context.exists?(action_name, view_path) ?
          view_path :
          [controller_path, DEFAULT_VIEW_DIRECTORY].join('/')
      end

      # Sets view prefixes for target view path.
      # @api protected
      def set_view_prefixes
        lookup_context.prefixes.prepend(target_view_path)
      end
  
      # Returns JavaScript view for ajax request or redirects to back as default.
      # @api protected
      # @return [Responce] JavaScript view for ajax request or redirects to back as default
      def return_back_or_ajax
        set_index_options
        respond_to do |format|
          if request.xhr?
            load_subscription_index(@index_options) if params[:reload].to_s.to_boolean(true)
            format.js
          # :skip-rails4:
          elsif Rails::VERSION::MAJOR >= 5
            redirect_back fallback_location: { action: :index }, **@index_options and return
          # :skip-rails4:
          # :skip-rails5:
          elsif request.referer
            redirect_to :back, **@index_options and return
          else
            redirect_to action: :index, **@index_options and return
          end
          # :skip-rails5:
        end
      end

  end
end
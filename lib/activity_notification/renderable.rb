module ActivityNotification
  # Provides logic for rendering notifications.
  # Handles both i18n strings support and smart partials rendering (different templates per notification key).
  # Deeply uses PublicActivity as reference
  module Renderable
    # Virtual attribute returning text description of the notification
    # using the notification's key to translate using i18n.
    def text(params = {})
      k = key.split('.')
      k.unshift('notification') if k.first != 'notification'
      if params.has_key?(:target)
        k.insert(1, params[:target])
      else
        k.insert(1, target.to_resource_name)
      end
      k.push('text')
      k = k.join('.')

      I18n.t(k, (parameters.merge(params) || {}).merge(group_member_count: group_member_count))
    end

    # Renders notification from views.
    #
    # @param [ActionView::Base] context
    # @return [nil] nil
    #
    # The preferred way of rendering notifications is
    # to provide a template specifying how the rendering should be happening.
    # However, you can choose using _I18n_ based approach when developing
    # an application that supports plenty of languages.
    #
    # If partial view exists that matches the "key" attribute
    # renders that partial with local variables set to contain both
    # Activity and activity_parameters (hash with indifferent access).
    #
    # If the partial view does not exist and you wish to fallback to rendering
    # through the I18n translation, you can do so by passing in a :fallback
    # parameter whose value equals :text.
    #
    # If you do not want to define a partial view, and instead want to have
    # all missing views fallback to a default, you can define the :fallback
    # value equal to the partial you wish to use when the partial defined
    # by the notification key does not exist.
    #
    # @example Render a list of all @target's notifications of from a view (erb)
    #   <ul>
    #     <% @target.notifications.each do |notification|  %>
    #       <li><%= render_notification(notification) %></li>
    #     <% end %>
    #   </ul>
    #
    # @example Fallback to the I18n text translation if the view is missing 
    #   <ul>
    #     <% @target.notifications.each do |notification|  %>
    #       <li><%= render_notification(notification, fallback: :text) %></li>
    #     <% end %>
    #   </ul>
    #
    # @example Fallback to a default view if the view for the current notification key is missing.
    # The string is the partial name you wish to use.
    #   <ul>
    #     <% @target.notifications.each do |notification|  %>
    #       <li><%= render_notification(notification, fallback: 'default') %></li>
    #     <% end %>
    #   </ul>
    #
    # # Layouts
    #TODO
    #
    # # Creating a template
    #
    # To use templates for formatting how the notification should render,
    # create a template based on target type and notification key, for example:
    #
    # Given a target type users and key _notification.article.create_, create directory tree
    # _app/views/activity_notifications/users/article/_ and create the _create_ partial there
    #
    # Note that if a key consists of more than three parts splitted by commas, your
    # directory structure will have to be deeper, for example:
    #   notification.article.comments.destroy => app/views/activity_notifications/users/articles/comments/_destroy.html.erb
    #
    # ## Custom Directory
    #TODO
    #
    # ## Variables in templates
    #TODO
    def render(context, params = {})
      params[:i18n] and return context.render text: self.text(params)

      partial = partial_path(*params.values_at(:partial, :partial_root, :target))
      layout  = layout_path(*params.values_at(:layout, :layout_root))
      locals  = prepare_locals(params)

      begin
        context.render params.merge(partial: partial, layout: layout, locals: locals)
      rescue ActionView::MissingTemplate => e
        if params[:fallback] == :text
          context.render text: self.text(params)
        elsif params[:fallback].present?
          partial = partial_path(*params.values_at(:fallback, :partial_root, :target))
          context.render params.merge(partial: partial, layout: layout, locals: locals)
        else
          raise e
        end
      end
    end

    def partial_path(path = nil, root = nil, target = nil)
      controller = ActivityNotification.get_controller         if ActivityNotification.respond_to?(:get_controller)
      root ||= "activity_notification/notifications/#{target}" if target.present?
      root ||= controller.target_view_path                     if controller.present? and controller.respond_to?(:target_view_path)
      root ||= 'activity_notification/notifications/default'
      path ||= self.key.gsub('.', '/')
      select_path(path, root)
    end

    def layout_path(path = nil, root = nil)
      path.nil? and return
      root ||= 'layouts'
      select_path(path, root)
    end

    def prepare_locals(params)
      locals = params.delete(:locals) || {}

      prepared_parameters = prepare_parameters(params)
      locals.merge\
        notification: self,
        parameters:   prepared_parameters
    end

    def prepare_parameters(params)
      @prepared_params ||= self.parameters.with_indifferent_access.merge(params)
    end

    private

      def select_path(path, root)
        [root, path].map(&:to_s).join('/')
      end

  end
end

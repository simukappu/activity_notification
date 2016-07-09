# ActivityNotification

Build Status is under construction

`activity_notification` provides integrated user activity notification for Rails. You can simply use `activity_notification` to configure multiple notification targets and make activity notifications with models, like adding comments, responding etc.
Currently, `activity_notification` is only supported with ActiveRecord ORM in Rails 4.


## Table of contents

1. [About](#about)
2. [Setup](#setup)
  1. [Gem installation](#gem-installation)
  2. [Database setup](#database-setup)
  3. [Configuring models](#configuring-models)
    1. [Configuring target model](#configuring-target-model)
    2. [Configuring notifiable model](#configuring-notifiable-model)
  4. [Configuring views](#configuring-views)
  5. [Configuring controllers](#configuring-controllers)
  6. [Configuring routes](#configuring-routes)
  7. [Creating notifications](#creating-notifications)
  8. [Displaying notifications](#displaying-notifications)
    1. [Preparing target notifications](#preparing-target-notifications)
    2. [Grouping notifications](#grouping-notifications)
    3. [Rendering notifications](#rendering-notifications)
    4. [Notification views](#notification-views)
    3. [i18n](#i18n)
  9. [Configuring email notifications](#configuring-email-notifications)
4. [Testing](#testing)
5. [Documentation](#documentation)
6. **[Common examples](#common-examples)**

## About

`activity_notification` provides following functions:
* Notification API (creating notifications and query for them)
* Notification controllers (open/unopen of notifications and link to notifiable activity page)
* Notification views (presentation of notifications)
* Notification grouping (like `"Tom and other 7 people posted comments to this article"`)
* Email notification
* Integration with [Devise](https://github.com/plataformatec/devise) authentication

`activity_notification` deeply uses [PublicActivity](https://github.com/pokonski/public_activity) as reference in presentation layer.

## Setup

### Gem installation

You can install `activity_notification` as you would any other gem:

```console
$ gem install activity_notification
```
or in your Gemfile:

```ruby
gem 'activity_notification'
```

!! WARNING: `activity_notification` has not been registered to Rubygems now.
This will be registered after testing and documentation are arranged.
Please install from github repository before you can get from Rubygems.

```ruby
gem 'activity_notification', git: 'https://github.com/simukappu/activity_notification'
```

After you install `activity_notification` and add it to your Gemfile, you need to run the generator:

```console
$ rails generate activity_notification:install
```

The generator will install an initializer which describes all configuration options of `activity_notification`.
This generator also generates a i18n based translation file which we can configure the presentation of notifications.

### Database setup

Currently `activity_notification` is only supported with ActiveRecord.
Create migration for notifications and migrate the database in your Rails project:

```console
$ rails generate activity_notification:migration
$ rake db:migrate
```

### Configuring models

#### Configuring target model

Configure your target model (e.g. app/models/user.rb).
Add including statement and `acts_as_target` definition to your target model which notifications are sent.

```ruby
class User < ActiveRecord::Base
  include ActivityNotification::Target
  # Example using confirmed_at of Device field to decide whether activity_notification sends notification email to this user
  acts_as_target email: :email, email_allowed: :confirmed_at
end
```

You can override several methods in your target model (e.g. notifications_index or notification_email_allowed?).

#### Configuring notifiable model

Configure your notifiable model (e.g. app/models/comment.rb).
Add including statement and `acts_as_notifiable` definition to your notifiable model representing activity to notify.
You have to define notification targets for all notifications created from the notifiable model. Other configurations are options.

```ruby
class Comment < ActiveRecord::Base
  belongs_to :article
  belongs_to :user

  include ActivityNotification::Notifiable
  # Example that ActivityNotification::Notifiable is configured with custom methods in your model as symbol
  acts_as_notifiable :users,
    targets: :custom_notification_users,
    group: :article,
    notifier: :user,
    email_allowed: :custom_notification_email_to_users_allowed?,
    notifiable_path: :custom_notifiable_path

  def custom_notification_users(key)
    User.where(id: self.article.comments.pluck(:user_id))
  end

  def custom_notification_email_to_users_allowed?(user, key)
    true
  end

  def custom_notifiable_path
    article_path(article)
  end

end
```

You can override several methods in your notifiable model (e.g. notifiable_path or notification_email_to_users_allowed?).

### Configuring views

`activity_notification` provides view template for your customization of notification views and view for default target will be generated.

```console
$ rails generate activity_notification:views
```

If you have multiple notification target model in your application (such as `User` and `Admin`), you will be able to have views based on the target like `notifications/users/index` and `notifications/admins/index`. If no view is found for the target, `activity_notification` will use the default view at `notifications/default/index`. You can also use the generator to generate target views:

```console
$ rails generate activity_notification:views users
```

If you would like to generate only a few sets of views, like the ones for the `notifications` (for notification views) and `mailer` (for notification email),
you can pass a list of modules to the generator with the `-v` flag.

```console
$ rails generate activity_notification:views -v mailer
```

### Configuring controllers

If the customization at the views level is not enough, you can customize each controller by following these steps:

1. Create your custom controllers using the generator which requires a target:

    ```console
    $ rails generate activity_notification:controllers users
    ```

    If you specify `users` as the target, controllers will be created in `app/controllers/users/`.
    And the notifications controller will look like this:

    ```ruby
    class Users::NotificationsController < ActivityNotification::NotificationsController
      # GET /:target_type/:target_id/notifcations
      # def index
      #   super
      # end
      ...
    end
    ```

2. Tell the router to use this controller:

    ```ruby
    notify_to :users, controllers: { notifcations: 'users/notifcations' }
    ```

3. Generate views from `activity_notification/notifcations/users` to `users/notifcations/users`. Since the controller was changed, it won't use the default views located in `activity_notification/notifcations/default`.

4. Finally, change or extend the desired controller actions.

    You can completely override a controller action
    ```ruby
    class Users::NotificationsController < ActivityNotification::NotificationsController
      # POST /:target_type/:target_id/notifcations/:id/open
      def open
        # custom open-notification code
      end
    end
    ```

### Configuring routes

`activity_notification` also provides routing helper. Add notification routing to config/routes.rb for the target (for example, `:users`):

```ruby
# Simply
Rails.application.routes.draw do
  notify_to :users
end

# Or integrated with devise
Rails.application.routes.draw do
  notify_to :users, with_devise: :users
end
```

### Creating notifications

You can trigger notifications by setting all your required parameters and triggering `notify`
on the notifiable model, like this:

```ruby
@comment.notify User key: 'article.commented_on', group: @comment.article
```

Or, you can call public API from `ActivityNotification::Notification.notify`

```ruby
ActivityNotification::Notification.notify User, @comment, group: @comment.article
```

### Displaying notifications

#### Preparing target notifications

To display them you can use `notifications` association of the target model:

```ruby
# custom_notifications_controller.rb
def index
  @notifications = @target.notifications
end
```

You can use several scope to filter notifications. For example, `unopened_only` to filter them unopened notifications only.

```ruby
# custom_notifications_controller.rb
def index
  @notifications = @target.notifications.unopened_only
end
```

Moreover, you can use `notifications_index` or `notifications_index_with_attributes` methods to automatically prepare notifications index for the target.

```ruby
# custom_notifications_controller.rb
def index
  @notifications = @target.notifications_index_with_attributes
end
```

#### Grouping notifications

`activity_notification` provides the function automatically grouping notifications. When you created a notification like this, all *unopened* notifications to the same target will be grouped by `article` as `:group` options:

```ruby
@comment.notify User key: 'article.commented_on', group: @comment.article
```

And you can render this in a view like this:
```erb
<% if notification.group_members_exists? %>
  <%= "#{notification.notifier.name} and other #{notification.group_members_count} people posted comments to your article \"#{notification.group.title}\"" %>
<% else %>
  <%= "#{notification.notifier.name} posted a comment to your article #{notification.notifiable.title}" %>
<% end %>
```

This presentation will be shown to target users as `Tom and other 7 people posted comments to your article "Let's use Ruby"`.

#### Rendering notifications

You can use `render_notifications` helper in your views to show the notifications index:

```erb
<%= render_notifications(@notifications) %>
```

We can set `:target` option to specify the target type of notifications:

```erb
<%= render_notifications(@notifications, target: :users) %>
```

*Note*: `render_notifications` is an alias for `render_notification` and does the same.

If you want to set notifications index in the common layout, such as common header, you can use `render_notifications_of` helper:

```shared/_header.html.erb
<%= render_notifications_of current_user, index_content: :with_attributes %>
```

Then, content named :notifications_index will be prepared and you can use it in your partial template.

```activity_notifications/notifications/users/_index.html.erb
...
<%= yield :notifications_index %>
...
```

##### Layouts

Under construction

##### Locals

Sometimes, it's desirable to pass additional local variables to partials. It can be done this way:

```erb
<%= render_notification(@notification, locals: {friends: current_user.friends}) %>
```

#### Notification views

`activity_notification` looks for views in `app/views/activity_notification/notifications/:target`.

For example, if you have an notification with `:key` set to `"notification.article.comment.relied"` and rendered it with `:target` set to `:users`, the gem will look for a partial in `app/views/activity_notification/notifications/users/article/comment/_relied.html.(|erb|haml|slim|something_else)`.

*Hint*: the `"notification."` prefix in `:key` is completely optional and kept for backwards compatibility, you can skip it in new projects.

If you would like to fallback to a partial, you can utilize the `fallback` parameter to specify the path of a partial to use when one is missing:

```erb
<%= render_notification(@notification, target: :users, fallback: 'default') %>
```

When used in this manner, if a partial with the specified `:key` cannot be located it will use the partial defined in the `fallback` instead. In the example above this would resolve to `activity_notification/notifications/users/_default.html.(|erb|haml|slim|something_else)`.

If you do not specify `:target` option,

```erb
<%= render_notification(@notification, fallback: 'default') %>
```

the gem will look for a partial in `default` as the target type which means `activity_notification/notifications/default/_default.html.(|erb|haml|slim|something_else)`.

If a view file does not exist then ActionView::MisingTemplate will be raised. If you wish to fallback to the old behaviour and use an i18n based translation in this situation you can specify a `:fallback` parameter of `text` to fallback to this mechanism like such:

```erb
<%= render_notification(@notification, fallback: :text) %>
```

#### i18n

Translations are used by the `#text` method, to which you can pass additional options in form of a hash. `#render` method uses translations when view templates have not been provided. You can render pure i18n strings by passing `{i18n: true}` to `#render_notification` or `#render`.

Translations should be put in your locale `.yml` files. To render pure strings from I18n example structure:

```yaml
notification:
  user:
    article:
      create: 'Article has been created'
      update: 'Someone has edited the article'
      destroy: 'Some user removed an article!'
      comment:
        replied: "<p>%{notifier_name} posted comment to your article %{article_title}</p>"
```

This structure is valid for notifications with keys `"notification.article.comment.replied"` or `"article.comment.replied"`. As mentioned before, `"notification."` part of the key is optional. In addition for above example, `%{notifier_name}` and `%{article_title}` are used from parameter field in the notification record.

### Configuring email notification

#### Setup mailer

First, you need to set up the default URL options for the `activity_notification` mailer in each environment. Here is a possible configuration for `config/environments/development.rb`:

```ruby
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
```

#### Notification email views

`activity_notification` will look for email template in the same way as notification views. For example, if you have an notification with `:key` set to `"notification.article.comment.relied"` and target_type `users`, the gem will look for a partial in `app/views/activity_notification/mailer/users/article/comment/_relied.html.(|erb|haml|slim|something_else)`.

If this template is missing, the gem will look for a partial in `default` as the target type which means `activity_notification/mailer/default/_default.html.(|erb|haml|slim|something_else)`.

#### i18n

The subject of notification email can be put in your locale `.yml` files as `mail_subject` field:

```yaml
notification:
  user:
    article:
      comment:
        replied: "<p>%{notifier_name} posted comment to your article %{article_title}</p>"
          mail_subject: 'New comment to your article'
```

## Testing

Under construction

## Documentation

Under construction

## Common examples

Under construction

## Help

Under construction

## License

`activity_notification` project rocks and uses [MIT License](https://github.com/simukappu/activity_notification/blob/master/MIT-LICENSE).

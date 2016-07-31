# ActivityNotification

[![Build Status](https://travis-ci.org/simukappu/activity_notification.svg?branch=master)](https://travis-ci.org/simukappu/activity_notification)
[![Coverage Status](https://coveralls.io/repos/github/simukappu/activity_notification/badge.svg?branch=master)](https://coveralls.io/github/simukappu/activity_notification?branch=master)
[![Code Climate](https://codeclimate.com/github/simukappu/activity_notification/badges/gpa.svg)](https://codeclimate.com/github/simukappu/activity_notification)
[![Gem Version](https://badge.fury.io/rb/activity_notification.svg)](https://badge.fury.io/rb/activity_notification)
[![MIT License](http://img.shields.io/badge/license-MIT-blue.svg?style=flat)](MIT-LICENSE)

`activity_notification` provides integrated user activity notifications for Rails. You can easily use it to configure multiple notification targets and make activity notifications with notifiable models, like adding comments, responding etc.

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
    2. [Rendering notifications](#rendering-notifications)
    3. [Notification views](#notification-views)
    4. [i18n for notifications](#i18n-for-notifications)
    5. [Grouping notifications](#grouping-notifications)
  9. [Configuring email notification](#configuring-email-notification)
    1. [Setup mailer](#setup-mailer)
    2. [Email templates](#email-templates)
    3. [i18n for email](#i18n-for-email)
4. [Testing](#testing)
5. [Documentation](#documentation)
6. **[Common examples](#common-examples)**

## About

`activity_notification` provides following functions:
* Notification API (creating notifications, query for notifications and managing notification parameters)
* Notification controllers (managing open/unopen of notifications, link to notifiable activity page)
* Notification views (presentation of notifications)
* Notification grouping (grouping like `"Tom and other 7 people posted comments to this article"`)
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

After you install `activity_notification` and add it to your Gemfile, you need to run the generator:

```console
$ rails generate activity_notification:install
```

The generator will install an initializer which describes all configuration options of `activity_notification`.
It also generates a i18n based translation file which we can configure the presentation of notifications.

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
Add `acts_as_notification_target` configuration to your target model to get notifications.

```ruby
class User < ActiveRecord::Base
  # Example using confirmed_at of Device field
  # to decide whether activity_notification sends notification email to this user
  acts_as_notification_target email: :email, email_allowed: :confirmed_at
end
```

*Note*: `acts_as_target` is an alias for `acts_as_notification_target` and does the same.

You can override several methods in your target model (e.g. `notification_index` or `notification_email_allowed?`).

#### Configuring notifiable model

Configure your notifiable model (e.g. app/models/comment.rb).
Add `acts_as_notifiable` configuration to your notifiable model representing activity to notify.
You have to define notification targets for all notifications from this notifiable model by `:targets` option. Other configurations are options.

```ruby
class Comment < ActiveRecord::Base
  belongs_to :article
  belongs_to :user

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

You can override several methods in your notifiable model (e.g. `notifiable_path` or `notification_email_allowed?`).

### Configuring views

`activity_notification` provides view templates to customize your notification views. The view generater can generate default views for all targets.

```console
$ rails generate activity_notification:views
```

If you have multiple target models in your application, such as `User` and `Admin`, you will be able to have views based on the target like `notifications/users/index` and `notifications/admins/index`. If no view is found for the target, `activity_notification` will use the default view at `notifications/default/index`. You can also use the generator to generate views for the specified target:

```console
$ rails generate activity_notification:views users
```

If you would like to generate only a few sets of views, like the ones for the `notifications` (for notification views) and `mailer` (for notification email views),
you can pass a list of modules to the generator with the `-v` flag.

```console
$ rails generate activity_notification:views -v mailer
```

### Configuring controllers

If the customization at the views level is not enough, you can customize each controller by following these steps:

1. Create your custom controllers using the generator with a target:

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
      ...
    end
    ```

### Configuring routes

`activity_notification` also provides routing helper. Add notification routing to `config/routes.rb` for the target (e.g. `:users`):

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

Or, you can call public API as `ActivityNotification::Notification.notify`

```ruby
ActivityNotification::Notification.notify User, @comment, group: @comment.article
```

### Displaying notifications

#### Preparing target notifications

To display notifications, you can use `notifications` association of the target model:

```ruby
# custom_notifications_controller.rb
def index
  @notifications = @target.notifications
end
```

You can also use several scope to filter notifications. For example, `unopened_only` to filter them unopened notifications only.

```ruby
# custom_notifications_controller.rb
def index
  @notifications = @target.notifications.unopened_only
end
```

Moreover, you can use `notification_index` or `notification_index_with_attributes` methods to automatically prepare notification index for the target.

```ruby
# custom_notifications_controller.rb
def index
  @notifications = @target.notification_index_with_attributes
end
```

#### Rendering notifications

You can use `render_notifications` helper in your views to show the notification index:

```erb
<%= render_notifications(@notifications) %>
```

We can set `:target` option to specify the target type of notifications:

```erb
<%= render_notifications(@notifications, target: :users) %>
```

*Note*: `render_notifications` is an alias for `render_notification` and does the same.

If you want to set notification index in the common layout, such as common header, you can use `render_notifications_of` helper like this:

```shared/_header.html.erb
<%= render_notifications_of current_user, index_content: :with_attributes %>
```

Then, content named :notification_index will be prepared and you can use it in your partial template.

```activity_notifications/notifications/users/_index.html.erb
...
<%= yield :notification_index %>
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

For example, if you have an notification with `:key` set to `"notification.article.comment.replied"` and rendered it with `:target` set to `:users`, the gem will look for a partial in `app/views/activity_notification/notifications/users/article/comment/_replied.html.(|erb|haml|slim|something_else)`.

*Hint*: the `"notification."` prefix in `:key` is completely optional and kept for backwards compatibility, you can skip it in new projects.

If you would like to fallback to a partial, you can utilize the `fallback` parameter to specify the path of a partial to use when one is missing:

```erb
<%= render_notification(@notification, target: :users, fallback: 'default') %>
```

When used in this manner, if a partial with the specified `:key` cannot be located it will use the partial defined in the `fallback` instead. In the example above this would resolve to `activity_notification/notifications/users/_default.html.(|erb|haml|slim|something_else)`.

If you do not specify `:target` option like this,

```erb
<%= render_notification(@notification, fallback: 'default') %>
```

the gem will look for a partial in `default` as the target type which means `activity_notification/notifications/default/_default.html.(|erb|haml|slim|something_else)`.

If a view file does not exist then ActionView::MisingTemplate will be raised. If you wish to fallback to the old behaviour and use an i18n based translation in this situation you can specify a `:fallback` parameter of `text` to fallback to this mechanism like such:

```erb
<%= render_notification(@notification, fallback: :text) %>
```

#### i18n for notifications

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

#### Grouping notifications

`activity_notification` provides the function for automatically grouping notifications. When you created a notification like this, all *unopened* notifications to the same target will be grouped by `article` set as `:group` options:

```ruby
@comment.notify User key: 'article.commented_on', group: @comment.article
```

You can use `group_owners_only` scope to filter owner notifications representing each group:

```ruby
# custom_notifications_controller.rb
def index
  @notifications = @target.notifications.group_owners_only
end
```
`notification_index` and `notification_index_with_attributes` methods also use `group_owners_only` scope internally.

And you can render them in a view like this:
```erb
<% if notification.group_member_exists? %>
  <%= "#{notification.notifier.name} and other #{notification.group_member_count} people" %>
<% else %>
  <%= "#{notification.notifier.name}" %>
<% end %>
<%= "posted comments to your article \"#{notification.group.title}\"" %>
```

This presentation will be shown to target users as `Tom and other 7 people posted comments to your article "Let's use Ruby"`.

### Configuring email notification

#### Setup mailer

First, you need to set up the default URL options for the `activity_notification` mailer in each environment. Here is a possible configuration for `config/environments/development.rb`:

```ruby
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
```

#### Email templates

`activity_notification` will look for email template in the same way as notification views. For example, if you have an notification with `:key` set to `"notification.article.comment.replied"` and target_type `users`, the gem will look for a partial in `app/views/activity_notification/mailer/users/article/comment/_replied.html.(|erb|haml|slim|something_else)`.

If this template is missing, the gem will look for a partial in `default` as the target type which means `activity_notification/mailer/default/_default.html.(|erb|haml|slim|something_else)`.

#### i18n for email

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

`activity_notification` project rocks and uses [MIT License](MIT-LICENSE).

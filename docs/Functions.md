## Functions

### Email notification

_activity_notification_ provides email notification to the notification targets.

#### Mailer setup

Set up SMTP server configuration for _ActionMailer_. Then, you need to set up the default URL options for the _activity_notification_ mailer in each environment. Here is a possible configuration for _config/environments/development.rb_:

```ruby
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
```

Email notification is disabled as default. You can configure it to enable email notification in initializer _activity_notification.rb_.

```ruby
config.email_enabled = true
```

You can also configure them for each model by _acts_as roles_ like these:

```ruby
class User < ActiveRecord::Base
  # Example using confirmed_at of devise field
  # to decide whether activity_notification sends notification email to this user
  acts_as_target email: :email, email_allowed: :confirmed_at
end
```

```ruby
class Comment < ActiveRecord::Base
  belongs_to :article
  belongs_to :user

  acts_as_notifiable :users,
    targets: ->(comment, key) {
      ([comment.article.user] + comment.article.reload.commented_users.to_a - [comment.user]).uniq
    },
    # Allow notification email
    email_allowed: true,
    notifiable_path: :article_notifiable_path

  def article_notifiable_path
    article_path(article)
  end
end
```

#### Sender configuration

You can configure the notification _"from"_ address inside of _activity_notification.rb_ in two ways.

Using a simple email address as _String_:

```ruby
config.mailer_sender = 'your_notification_sender@example.com'
```

Using a _Proc_ to configure the sender based on the _notification.key_:

```ruby
config.mailer_sender = ->(key){ key == 'inquiry.post' ? 'support@example.com' : 'noreply@example.com' }
```

#### Email templates

_activity_notification_ will look for email template in a similar way as notification views, but the view file name does not start with an underscore. For example, if you have a notification with _:key_ set to _"notification.comment.reply"_ and target_type _users_, the gem will look for a partial in _app/views/activity_notification/mailer/users/comment/reply.html.(|erb|haml|slim|something_else)_.

If this template is missing, the gem will use _default_ as the target type which means _activity_notification/mailer/default/default.html.(|erb|haml|slim|something_else)_.

#### Email subject

_activity_notification_ will use `"Notification of #{@notification.notifiable.printable_type.downcase}"` as default email subject. If it is defined, _activity_notification_ will resolve email subject from _overriding_notification_email_subject_ method in notifiable models. You can customize email subject like this:

```ruby
class Comment < ActiveRecord::Base
  belongs_to :article
  belongs_to :user

  acts_as_notifiable :users,
    targets: ->(comment, key) {
      ([comment.article.user] + comment.article.reload.commented_users.to_a - [comment.user]).uniq
    },
    notifiable_path: :article_notifiable_path

  def overriding_notification_email_subject(target, key)
    if key == "comment.create"
      "New comment to your article!"
    else
      "Notification for new comments!"
    end
  end
end

```

If you use i18n for email, you can configure email subject in your locale files. See [i18n for email](#i18n-for-email).

#### Other header fields

Similarly to the [Email subject](#email-subject), the `From`, `Reply-To` and `Message-ID` headers are configurable per notifiable model. From and reply to will override the `config.mailer_sender` config setting.

```ruby
class Comment < ActiveRecord::Base
  belongs_to :article
  belongs_to :user

  acts_as_notifiable :users,
    targets: ->(comment, key) {
      ([comment.article.user] + comment.article.commented_users.to_a - [comment.user]).uniq
    },
    notifiable_path: :article_notifiable_path

  def overriding_notification_email_from(target, key)
    "no-reply.article@example.com"
  end

  def overriding_notification_email_reply_to(target, key)
    "no-reply.article+comment-#{self.id}@example.com"
  end

  def overriding_notification_email_message_id(target, key)
    "https://www.example.com/article/#{article.id}@example.com/"
  end
end
```

#### i18n for email

The subject of notification email can be put in your locale _.yml_ files as **mail_subject** field:

```yaml
notification:
  user:
    comment:
      post:
        text: "<p>Someone posted comments to your article</p>"
        mail_subject: "New comment to your article"
```

### Batch email notification

_activity_notification_ provides batch email notification to the notification targets. You can send notification email daily, hourly or weekly and so on with a scheduler like _whenever_.

#### Batch mailer setup

Set up SMTP server configuration for _ActionMailer_ and the default URL options for the _activity_notification_ mailer in each environment.

Batch email notification is disabled as default. You can configure it to enable email notification in initializer _activity_notification.rb_ like single email notification.

```ruby
config.email_enabled = true
```

You can also configure them for each target model by _acts_as_target_ role like this.

```ruby
class User < ActiveRecord::Base
  # Example using confirmed_at of devise field
  # to decide whether activity_notification sends batch notification email to this user
  acts_as_target email: :email, batch_email_allowed: :confirmed_at
end
```

Then, you can send batch notification email for unopened notifications only to the all specified targets with _batch_key_.

```ruby
# Send batch notification email to the users with unopened notifications
User.send_batch_unopened_notification_email(batch_key: 'batch.comment.post')
```

You can also add conditions to filter notifications, like this:

```ruby
# Send batch notification email to the users with unopened notifications of specified key in 1 hour
User.send_batch_unopened_notification_email(batch_key: 'batch.comment.post', filtered_by_key: 'comment.post', custom_filter: ["created_at >= ?", time.hour.ago])
```

#### Batch sender configuration

_activity_notification_ uses same sender configuration of real-time email notification as batch email sender.
You can configure _config.mailer_sender_ as simply _String_ or _Proc_ based on the _batch_key_:

```ruby
config.mailer_sender = ->(batch_key){ batch_key == 'batch.inquiry.post' ? 'support@example.com' : 'noreply@example.com' }
```

_batch_key_ is specified by **:batch_key** option. If this option is not specified, the key of the first notification will be used as _batch_key_.

#### Batch email templates

_activity_notification_ will look for batch email template in the same way as email notification using _batch_key_.

#### Batch email subject

_activity_notification_ will resolve batch email subject as the same way as [email subject](#email-subject) with _batch_key_.

If you use i18n for batch email, you can configure batch email subject in your locale files. See [i18n for batch email](#i18n-for-batch-email).

#### i18n for batch email

The subject of batch notification email also can be put in your locale _.yml_ files as **mail_subject** field for _batch_key_.

```yaml
notification:
  user:
    batch:
      comment:
        post:
          mail_subject: "New comments to your article"
```

### Grouping notifications

_activity_notification_ provides the function for automatically grouping notifications. When you created a notification like this, all _unopened_ notifications to the same target will be grouped by _article_ set as **:group** options:

```ruby
@comment.notify :users key: 'comment.post', group: @comment.article
```

When you use default notification view, it is helpful to configure **acts_as_notification_group** (or _acts_as_group_) with _:printable_name_ option to render group instance.

```ruby
class Article < ActiveRecord::Base
  belongs_to :user
  acts_as_notification_group printable_name: ->(article) { "article \"#{article.title}\"" }
end
```

You can use **group_owners_only** scope to filter owner notifications representing each group:

```ruby
# custom_notifications_controller.rb
def index
  @notifications = @target.notifications.group_owners_only
end
```

_notification_index_ and _notification_index_with_attributes_ methods also use _group_owners_only_ scope internally.

And you can render them in a view like this:

```erb
<% if notification.group_member_exists? %>
  <%= "#{notification.notifier.name} and #{notification.group_member_count} other users" %>
<% else %>
  <%= "#{notification.notifier.name}" %>
<% end %>
<%= "posted comments to your article \"#{notification.group.title}\"" %>
```

This presentation will be shown to target users as _Kevin and 7 other users posted comments to your article "Let's use Ruby"_.

You can also use `%{group_member_count}`, `%{group_notification_count}`, `%{group_member_notifier_count}` and `%{group_notifier_count}` in i18n text as a field:

```yaml
notification:
  user:
    comment:
      post:
        text: "<p>%{notifier_name} and %{group_member_notifier_count} other users posted %{group_notification_count} comments to your article</p>"
        mail_subject: "New comment to your article"
```

Then, you will see _"Kevin and 7 other users posted 10 comments to your article"_.

### Subscription management

_activity_notification_ provides the function for subscription management of notifications and notification email.

#### Configuring subscriptions

Subscription management is disabled as default. You can configure it to enable subscription management in initializer _activity_notification.rb_.

```ruby
config.subscription_enabled = true
```

This makes all target model subscribers. You can also configure them for each target model by _acts_as_target_ role like this:

```ruby
class User < ActiveRecord::Base
  # Example using confirmed_at of devise field
  # to decide whether activity_notification manages subscriptions of this user
  acts_as_target email: :email, email_allowed: :confirmed_at, subscription_allowed: :confirmed_at
end
```

If you do not have a subscriptions table in you database, create a migration for subscriptions and migrate the database in your Rails project:

```console
$ bin/rails generate activity_notification:migration CreateSubscriptions -t subscriptions
$ bin/rake db:migrate
```

If you are using a different table name than the default "subscriptions", change the settings in your config/initializers/activity_notification.rb file, e.g, if you use the table name "notifications_subscription" instead:

```
config.subscription_table_name = "notifications_subscriptions"
```

#### Managing subscriptions

Subscriptions are managed by instances of **ActivityNotification::Subscription** model which belongs to _target_ and _key_ of the notification.
_Subscription#subscribing_ manages subscription of notifications.
_true_ means the target will receive the notifications with this key.
_false_ means the target will not receive these notifications.
_Subscription#subscribing_to_email_ manages subscription of notification email.
_true_ means the target will receive the notification email with this key including batch notification email with this _batch_key_.
_false_ means the target will not receive these notification email.

##### Subscription defaults

As default, all target subscribes to notification and notification email when subscription record does not exist in your database.
You can change this **subscribe_as_default** parameter in initializer _activity_notification.rb_.

```ruby
config.subscribe_as_default = false
```

Then, all target does not subscribe to notification and notification email and will not receive any notifications as default.

As default, email and optional target subscriptions will use the same default subscription value as defined in **subscribe_as_default**.
You can disable them by providing **subscribe_to_email_as_default** or **subscribe_to_optional_targets_as_default** parameter(s) in initializer _activity_notification.rb_.

```ruby
# Enable subscribe as default, but disable it for emails
config.subscribe_as_default = true
config.subscribe_to_email_as_default = false
config.subscribe_to_optional_targets_as_default = true
```

However if **subscribe_as_default** is not enabled, **subscribe_to_email_as_default** and **subscribe_to_optional_targets_as_default** won't change anything.

##### Creating and updating subscriptions

You can create subscription record from subscription API in your target model like this:

```ruby
# Subscribe 'comment.reply' notifications and notification email
user.create_notification_subscription(key: 'comment.reply')

# Subscribe 'comment.reply' notifications but does not subscribe notification email
user.create_notification_subscription(key: 'comment.reply', subscribing_to_email: false)

# Unsubscribe 'comment.reply' notifications and notification email
user.create_notification_subscription(key: 'comment.reply', subscribing: false)
```

You can also update subscriptions like this:

```ruby
# Subscribe 'comment.reply' notifications and notification email
user.find_or_create_notification_subscription('comment.reply').subscribe

# Unsubscribe 'comment.reply' notifications and notification email
user.find_or_create_notification_subscription('comment.reply').unsubscribe

# Unsubscribe 'comment.reply' notification email
user.find_or_create_notification_subscription('comment.reply').unsubscribe_to_email
```

#### Customizing subscriptions

_activity_notification_ provides basic controllers and views to manage the subscriptions.

Add subscription routing to _config/routes.rb_ for the target (e.g. _:users_):

```ruby
Rails.application.routes.draw do
  subscribed_by :users
end
```

or, you can also configure it with notifications like this:

```ruby
Rails.application.routes.draw do
  notify_to :users, with_subscription: true
end
```

Then, you can access _users/1/subscriptions_ and use _[ActivityNotification::SubscriptionsController](/app/controllers/activity_notification/subscriptions_controller.rb)_ or _[ActivityNotification::SubscriptionsWithDeviseController](/app/controllers/activity_notification/subscriptions_with_devise_controller.rb)_ to manage the subscriptions.

You can see sample subscription management view in demo application here: *https://activity-notification-example.herokuapp.com/users/1/subscriptions*

If you would like to customize subscription controllers or views, you can use generators like notifications:

- Customize subscription controllers

  1. Create your custom controllers using controller generator with a target:

     ```console
     $ bin/rails generate activity_notification:controllers users -c subscriptions subscriptions_with_devise
     ```

  2. Tell the router to use this controller:

     ```ruby
     notify_to :users, with_subscription: { controller: 'users/subscriptions' }
     ```

- Customize subscription views

  ```console
  $ bin/rails generate activity_notification:views users -v subscriptions
  ```

### REST API backend

_activity_notification_ provides REST API backend to operate notifications and subscriptions.

#### Configuring REST API backend

You can configure _activity_notification_ routes as REST API backend with **:api_mode** option of _notify_to_ method. See [Routes as REST API backend](#routes-as-rest-api-backend) for more details. With _:api_mode_ option, _activity_notification_ uses _[ActivityNotification::NotificationsApiController](/app/controllers/activity_notification/notifications_api_controller.rb)_ instead of _[ActivityNotification::NotificationsController](/app/controllers/activity_notification/notifications_controller.rb)_.

In addition, you can use _:with_subscription_ option with _:api_mode_ to enable subscription management like this:

```ruby
Rails.application.routes.draw do
  scope :api do
    scope :"v2" do
      notify_to :users, api_mode: true, with_subscription: true
    end
  end
end
```

Then, _activity_notification_ uses _[ActivityNotification::SubscriptionsApiController](/app/controllers/activity_notification/subscriptions_api_controller.rb)_ instead of _[ActivityNotification::SubscriptionsController](/app/controllers/activity_notification/subscriptions_controller.rb)_, and you can call _activity_notification_ REST API as _/api/v2/notifications_ and _/api/v2/subscriptions_ from your frontend application.

When you want to use REST API backend integrated with Devise authentication, see [REST API backend with Devise Token Auth](#rest-api-backend-with-devise-token-auth).

You can see [sample single page application](/spec/rails_app/app/javascript/) using [Vue.js](https://vuejs.org) as a part of example Rails application. This sample application works with _activity_notification_ REST API backend.

#### API reference as OpenAPI Specification

_activity_notification_ provides API reference as [OpenAPI Specification](https://github.com/OAI/OpenAPI-Specification).

OpenAPI Specification in [online demo](https://activity-notification-example.herokuapp.com/) is published here: **https://activity-notification-example.herokuapp.com/api/v2/apidocs**

Public API reference is also hosted in [SwaggerHub](https://swagger.io/tools/swaggerhub/) here: **https://app.swaggerhub.com/apis-docs/simukappu/activity-notification/**

You can also publish OpenAPI Specification in your own application using _[ActivityNotification::ApidocsController](/app/controllers/activity_notification/apidocs_controller.rb)_ like this:

```ruby
Rails.application.routes.draw do
  scope :api do
    scope :"v2" do
      resources :apidocs, only: [:index], controller: 'activity_notification/apidocs'
    end
  end
end
```

You can use [Swagger UI](https://swagger.io/tools/swagger-ui/) with this OpenAPI Specification to visualize and interact with _activity_notification_ API’s resources.

### Integration with Devise

_activity_notification_ supports to integrate with devise authentication.

#### Configuring integration with Devise authentication

Add **:with_devise** option in notification routing to _config/routes.rb_ for the target:

```ruby
Rails.application.routes.draw do
  devise_for :users
  # Integrated with Devise
  notify_to :users, with_devise: :users
end
```

Then _activity_notification_ will use _[ActivityNotification::NotificationsWithDeviseController](/app/controllers/activity_notification/notifications_with_devise_controller.rb)_ as a notifications controller. The controller actions automatically call _authenticate_user!_ and the user will be restricted to access and operate own notifications only, not others'.

_Hint_: HTTP 403 Forbidden will be returned for unauthorized notifications.

#### Using different model as target

You can also use different model from Devise resource as a target. When you will add this to _config/routes.rb_:

```ruby
Rails.application.routes.draw do
  devise_for :users
  # Integrated with Devise for different model
  notify_to :admins, with_devise: :users
end
```

and add **:devise_resource** option to _acts_as_target_ in the target model:

```ruby
class Admin < ActiveRecord::Base
  belongs_to :user
  acts_as_target devise_resource: :user
end
```

_activity_notification_ will authenticate _:admins_ notifications with devise authentication for _:users_.
In this example, _activity_notification_ will confirm _admin_ belonging to authenticated _user_ by Devise.

#### Configuring simple default routes

You can configure simple default routes for authenticated users, like _/notifications_ instead of _/users/1/notifications_. Use **:devise_default_routes** option like this:

```ruby
Rails.application.routes.draw do
  devise_for :users
  notify_to :users, with_devise: :users, devise_default_routes: true
end
```

If you use multiple notification targets with Devise, you can also use this option with scope like this:

```ruby
Rails.application.routes.draw do
  devise_for :users
  # Integrated with Devise for different model, and use with scope
  scope :admins, as: :admins do
    notify_to :admins, with_devise: :users, devise_default_routes: true, routing_scope: :admins
  end
end
```

Then, you can access _/admins/notifications_ instead of _/admins/1/notifications_.

#### REST API backend with Devise Token Auth

We can also integrate [REST API backend](#rest-api-backend) with [Devise Token Auth](https://github.com/lynndylanhurley/devise_token_auth).
Use **:with_devise** option with **:api_mode** option _config/routes.rb_ for the target like this:

```ruby
Rails.application.routes.draw do
  devise_for :users
  # Configure authentication API with Devise Token Auth
  namespace :api do
    scope :"v2" do
      mount_devise_token_auth_for 'User', at: 'auth'
    end
  end
  # Integrated with Devise Token Auth
  scope :api do
    scope :"v2" do
      notify_to :users, api_mode: true, with_devise: :users, with_subscription: true
    end
  end
end
```

You can also configure it as simple default routes and with different model from Devise resource as a target:

```ruby
Rails.application.routes.draw do
  devise_for :users
  # Configure authentication API with Devise Token Auth
  namespace :api do
    scope :"v2" do
      mount_devise_token_auth_for 'User', at: 'auth'
    end
  end
  # Integrated with Devise Token Auth as simple default routes and with different model from Devise resource as a target
  scope :api do
    scope :"v2" do
      scope :admins, as: :admins do
        notify_to :admins, api_mode: true, with_devise: :users, devise_default_routes: true, with_subscription: true
      end
    end
  end
end
```

Then _activity_notification_ will use _[ActivityNotification::NotificationsApiWithDeviseController](/app/controllers/activity_notification/notifications_api_with_devise_controller.rb)_ as a notifications controller. The controller actions automatically call _authenticate_user!_ and the user will be restricted to access and operate own notifications only, not others'.

##### Configuring Devise Token Auth

At first, you have to set up [Devise Token Auth configuration](https://devise-token-auth.gitbook.io/devise-token-auth/config). You also have to configure your target model like this:

```ruby
class User < ActiveRecord::Base
  devise :database_authenticatable, :confirmable
  include DeviseTokenAuth::Concerns::User
  acts_as_target
end
```

##### Using REST API backend with Devise Token Auth

To sign in and get _access-token_ from Devise Token Auth, call _sign_in_ API which you configured by _mount_devise_token_auth_for_ method:

```console
$ curl -X POST -H "Content-Type: application/json" -D - -d '{"email": "ichiro@example.com","password": "changeit"}' https://activity-notification-example.herokuapp.com/api/v2/auth/sign_in


HTTP/1.1 200 OK
...
Content-Type: application/json; charset=utf-8
access-token: ZiDvw8vJGtbESy5Qpw32Kw
token-type: Bearer
client: W0NkGrTS88xeOx4VDOS-Xg
expiry: 1576387310
uid: ichiro@example.com
...

{
  "data": {
    "id": 1,
    "email": "ichiro@example.com",
    "provider": "email",
    "uid": "ichiro@example.com",
    "name": "Ichiro"
  }
}
```

Then, call _activity_notification_ API with returned _access-token_, _client_ and _uid_ as HTTP headers:

```console
$ curl -X GET -H "Content-Type: application/json" -H "access-token: ZiDvw8vJGtbESy5Qpw32Kw" -H "client: W0NkGrTS88xeOx4VDOS-Xg" -H "uid: ichiro@example.com" -D - https://activity-notification-example.herokuapp.com/api/v2/notifications

HTTP/1.1 200 OK
...

{
  "count": 7,
  "notifications": [
    ...
  ]
}
```

Without valid _access-token_, API returns _401 Unauthorized_:

```console
$ curl -X GET -H "Content-Type: application/json" -D - https://activity-notification-example.herokuapp.com/api/v2/notifications

HTTP/1.1 401 Unauthorized
...

{
  "errors": [
    "You need to sign in or sign up before continuing."
  ]
}
```

When you request restricted resources of unauthorized targets, _activity_notification_ API returns _403 Forbidden_:

```console
$ curl -X GET -H "Content-Type: application/json" -H "access-token: ZiDvw8vJGtbESy5Qpw32Kw" -H "client: W0NkGrTS88xeOx4VDOS-Xg" -H "uid: ichiro@example.com" -D - https://activity-notification-example.herokuapp.com/api/v2/notifications/1

HTTP/1.1 403 Forbidden
...

{
  "gem": "activity_notification",
  "error": {
    "code": 403,
    "message": "Forbidden because of invalid parameter",
    "type": "Wrong target is specified"
  }
}
```

See [Devise Token Auth documents](https://devise-token-auth.gitbook.io/devise-token-auth/) for more details.

### Push notification with Action Cable

_activity_notification_ supports push notification with Action Cable by WebSocket.
_activity_notification_ only provides Action Cable channels implementation, does not connections.
You can use default implementaion in Rails or your custom `ApplicationCable::Connection` for Action Cable connections.

#### Enabling broadcasting notifications to channels

Broadcasting notifications to Action Cable channels is provided as [optional notification targets implementation](#action-cable-channels-as-optional-target).
This optional targets is disabled as default. You can configure it to enable Action Cable broadcasting in initializer _activity_notification.rb_.

```ruby
# Enable Action Cable broadcasting as HTML view
config.action_cable_enabled = true
# Enable Action Cable API broadcasting as formatted JSON
config.action_cable_api_enabled = true
```

You can also configure them for each model by _acts_as roles_ like these:

```ruby
class User < ActiveRecord::Base
  # Allow Action Cable broadcasting
  acts_as_target action_cable_allowed: true
end
```

```ruby
class Comment < ActiveRecord::Base
  belongs_to :article
  belongs_to :user

  acts_as_notifiable :users,
    targets: ->(comment, key) {
      ([comment.article.user] + comment.article.reload.commented_users.to_a - [comment.user]).uniq
    },
    # Allow Action Cable broadcasting as HTML view
    action_cable_allowed: true,
    # Enable Action Cable API broadcasting as formatted JSON
    action_cable_api_allowed: true
end
```

Then, _activity_notification_ will broadcast configured notifications to target channels by _[ActivityNotification::OptionalTarget::ActionCableChannel](/lib/activity_notification/optional_targets/action_cable_channel.rb)_ and/or _[ActivityNotification::OptionalTarget::ActionCableApiChannel](/lib/activity_notification/optional_targets/action_cable_api_channel.rb)_ as optional targets.

#### Subscribing notifications from channels

_activity_notification_ provides _[ActivityNotification::NotificationChannel](/app/channels/activity_notification/notification_channel.rb)_ and _[ActivityNotification::NotificationApiChannel](/app/channels/activity_notification/notification_api_channel.rb)_ to subscribe broadcasted notifications with Action Cable.

You can simply create subscriptions for the specified target in your view like this:

```js
<script type="text/javascript" src="https://cdnjs.cloudflare.com/ajax/libs/push.js/1.0.9/push.min.js"></script>
<script>
  App.activity_notification = App.cable.subscriptions.create(
    {
      channel: "ActivityNotification::NotificationChannel",
      target_type: "<%= @target.to_class_name %>", target_id: "<%= @target.id %>"
    },
    {
      connected: function() {
        // Connected
      },
      disconnected: function() {
        // Disconnected
      },
      rejected: function() {
        // Rejected
      },
      received: function(notification) {
        // Display notification

        // Push notificaion using Web Notification API by Push.js
        Push.create('ActivityNotification', {
          body: notification.text,
          timeout: 5000,
          onClick: function () {
            location.href = notification.notifiable_path;
            this.close();
          }
        });
      }
    }
  );
</script>
```

or create subscriptions in your single page application with API channels like this:

```js
// Vue.js implementation with actioncable-vue
export default {
  // ...
  mounted() {
    this.subscribeActionCable();
  },
  channels: {
    "ActivityNotification::NotificationApiChannel": {
      connected() {
        // Connected
      },
      disconnected() {
        // Disconnected
      },
      rejected() {
        // Rejected
      },
      received(data) {
        this.notify(data);
      },
    },
  },
  methods: {
    subscribeActionCable() {
      this.$cable.subscribe({
        channel: "ActivityNotification::NotificationApiChannel",
        target_type: this.target_type,
        target_id: this.target_id,
      });
    },
    notify(data) {
      // Display notification

      // Push notificaion using Web Notification API by Push.js
      Push.create("ActivityNotification", {
        body: data.notification.text,
        timeout: 5000,
        onClick: function () {
          location.href = data.notification.notifiable_path;
          this.close();
        },
      });
    },
  },
};
```

Then, _activity_notification_ will push desktop notification using Web Notification API.

#### Subscribing notifications with Devise authentication

To use Devise integration, enable subscribing notifications with Devise authentication in initializer _activity_notification.rb_.

```ruby
config.action_cable_with_devise = true
```

You can also configure them for each target model by _acts_as_target_ like this:

```ruby
class User < ActiveRecord::Base
  acts_as_target action_cable_allowed: true,
    # Allow Action Cable broadcasting and enable subscribing notifications with Devise authentication
    action_cable_with_devise: true
end
```

When you set _action_cable_with_devise_ option to _true_, _ActivityNotification::NotificationChannel_ will reject your subscription requests for the target type.

_activity_notification_ also provides _[ActivityNotification::NotificationWithDeviseChannel](/app/channels/activity_notification/notification_with_devise_channel.rb)_ to create subscriptions integrated with Devise authentication.
You can simply use _ActivityNotification::NotificationWithDeviseChannel_ instead of _ActivityNotification::NotificationChannel_:

```js
App.activity_notification = App.cable.subscriptions.create(
  {
    channel: "ActivityNotification::NotificationWithDeviseChannel",
    target_type: "<%= @target.to_class_name %>",
    target_id: "<%= @target.id %>",
  },
  {
    // ...
  }
);
```

You can also create these subscriptions with _devise_type_ parameter instead of _target_id_ parameter like this:

```js
App.activity_notification = App.cable.subscriptions.create(
  {
    channel: "ActivityNotification::NotificationWithDeviseChannel",
    target_type: "users",
    devise_type: "users",
  },
  {
    // ...
  }
);
```

_ActivityNotification::NotificationWithDeviseChannel_ will confirm subscription requests from authenticated cookies by Devise. If the user has not signed in, the subscription request will be rejected. If the user has signed in as unauthorized user, the subscription request will be also rejected.

In addtion, you can use `Target#notification_action_cable_channel_class_name` method to select channel class depending on your _action_cable_with_devise_ configuration for the target.

```js
App.activity_notification = App.cable.subscriptions.create(
  {
    channel: "<%= @target.notification_action_cable_channel_class_name %>",
    target_type: "<%= @target.to_class_name %>",
    target_id: "<%= @target.id %>",
  },
  {
    // ...
  }
);
```

This script is also implemented in [default notifications index view](/app/views/activity_notification/notifications/default/index.html.erb) of _activity_notification_.

#### Subscribing notifications API with Devise Token Auth

To use Devise Token Auth integration, also enable subscribing notifications with Devise authentication in initializer _activity_notification.rb_.

```ruby
config.action_cable_with_devise = true
```

You can also configure them for each target model by _acts_as_target_ like this:

```ruby
class User < ActiveRecord::Base
  acts_as_target action_cable_api_allowed: true,
    # Allow Action Cable broadcasting and enable subscribing notifications API with Devise Token Auth
    action_cable_with_devise: true
end
```

When you set _action_cable_with_devise_ option to _true_, _ActivityNotification::NotificationApiChannel_ will reject your subscription requests for the target type.

_activity_notification_ also provides _[ActivityNotification::NotificationApiWithDeviseChannel](/app/channels/activity_notification/notification_api_with_devise_channel.rb)_ to create subscriptions integrated with Devise Token Auth.
You can simply use _ActivityNotification::NotificationApiWithDeviseChannel_ instead of _ActivityNotification::NotificationApiChannel_. Note that you have to pass authenticated token by Devise Token Auth in subscription requests like this:

```js
export default {
  // ...
  channels: {
    "ActivityNotification::NotificationApiWithDeviseChannel": {
      // ...
    },
  },
  methods: {
    subscribeActionCable() {
      this.$cable.subscribe({
        channel: "ActivityNotification::NotificationApiWithDeviseChannel",
        target_type: this.target_type,
        target_id: this.target_id,
        "access-token": this.authHeaders["access-token"],
        client: this.authHeaders["client"],
        uid: this.authHeaders["uid"],
      });
    },
  },
};
```

You can also create these subscriptions with _devise_type_ parameter instead of _target_id_ parameter like this:

```js
export default {
  // ...
  methods: {
    subscribeActionCable() {
      this.$cable.subscribe({
        channel: "ActivityNotification::NotificationApiWithDeviseChannel",
        target_type: "users",
        devise_type: "users",
        "access-token": this.authHeaders["access-token"],
        client: this.authHeaders["client"],
        uid: this.authHeaders["uid"],
      });
    },
  },
};
```

_ActivityNotification::NotificationWithDeviseChannel_ will confirm subscription requests from authenticated token by Devise Token Auth. If the token is invalid, the subscription request will be rejected. If the token of unauthorized user is passed, the subscription request will be also rejected.

This script is also implemented in [notifications index in sample single page application](/spec/rails_app/app/javascript/components/notifications/Index.vue).

#### Subscription management of Action Cable channels

Since broadcasting notifications to Action Cable channels is provided as [optional notification targets implementation](#action-cable-channels-as-optional-target), you can manage subscriptions as _:action_cable_channel_ and _:action_cable_api_channel_ optional target. See [subscription management of optional targets](#subscription-management-of-optional-targets) for more details.

### Optional notification targets

_activity_notification_ supports configurable optional notification targets like Amazon SNS, Slack, SMS and so on.

#### Configuring optional targets

_activity_notification_ provides default optional target implementation for Amazon SNS and Slack.
You can develop any optional target classes which extends _ActivityNotification::OptionalTarget::Base_, and configure them to notifiable model by _acts_as_notifiable_ like this:

```ruby
class Comment < ActiveRecord::Base
  belongs_to :article
  belongs_to :user

  require 'activity_notification/optional_targets/amazon_sns'
  require 'activity_notification/optional_targets/slack'
  require 'custom_optional_targets/console_output'
  acts_as_notifiable :admins, targets: [Admin.first].compact,
    notifiable_path: :article_notifiable_path,
    # Set optional target implementation class and initializing parameters
    optional_targets: {
      ActivityNotification::OptionalTarget::AmazonSNS => { topic_arn: 'arn:aws:sns:XXXXX:XXXXXXXXXXXX:XXXXX' },
      ActivityNotification::OptionalTarget::Slack  => {
        webhook_url: 'https://hooks.slack.com/services/XXXXXXXXX/XXXXXXXXX/XXXXXXXXXXXXXXXXXXXXXXXX',
        slack_name: :slack_name, channel: 'activity_notification', username: 'ActivityNotification', icon_emoji: ":ghost:"
      },
      CustomOptionalTarget::ConsoleOutput => {}
    }

  def article_notifiable_path
    article_path(article)
  end
end
```

Write _require_ statement for optional target implementation classes and set them with initializing parameters to _acts_as_notifiable_.
_activity_notification_ will publish all notifications of those targets and notifiables to optional targets.

#### Customizing message format

Optional targets prepare publishing messages from notification instance using view template like rendering notifications.
As default, all optional targets use _app/views/activity_notification/optional_targets/default/base/\_default.text.erb_.
You can customize this template by creating _app/views/activity_notification/optional_targets/<target_class_name>/<optional_target_class_name>/<notification_key>.text.(|erb|haml|slim|something_else)_.
For example, if you have a notification for _:users_ target with _:key_ set to _"notification.comment.reply"_ and _ActivityNotification::OptionalTarget::AmazonSNS_ optional target is configured, the gem will look for a partial in _app/views/activity_notification/optional_targets/users/amazon_sns/comment/\_reply.text.erb_.
The gem will also look for templates whose _<target_class_name>_ is _default_, _<optional_target_class_name>_ is _base_ and _<notification_key>_ is _default_, which means _app/views/activity_notification/optional_targets/users/amazon_sns/\_default.text.erb_, _app/views/activity_notification/optional_targets/users/base/\_default.text.erb_, _app/views/activity_notification/optional_targets/default/amazon_sns/\_default.text.erb_ and _app/views/activity_notification/optional_targets/default/base/\_default.text.erb_.

#### Action Cable channels as optional target

_activity_notification_ provides **ActivityNotification::OptionalTarget::ActionCableChannel** and **ActivityNotification::OptionalTarget::ActionCableApiChannel** as default optional target implementation to broadcast notifications to Action Cable channels.

Simply write `require 'activity_notification/optional_targets/action_cable_channel'` or `require 'activity_notification/optional_targets/action_cable_api_channel'` statement in your notifiable model and set _ActivityNotification::OptionalTarget::ActionCableChannel_ or _ActivityNotification::OptionalTarget::ActionCableApiChannel_ to _acts_as_notifiable_ with initializing parameters. If you don't specify initializing parameters _ActivityNotification::OptionalTarget::ActionCableChannel_ and _ActivityNotification::OptionalTarget::ActionCableApiChannel_ uses configuration in _ActivityNotification.config_.

```ruby
# Set Action Cable broadcasting as HTML view using optional target
class Comment < ActiveRecord::Base
  require 'activity_notification/optional_targets/action_cable_channel'
  acts_as_notifiable :admins, targets: [Admin.first].compact,
    optional_targets: {
      ActivityNotification::OptionalTarget::ActionCableChannel => { channel_prefix: 'admin_notification' }
    }
end
```

```ruby
# Set Action Cable API broadcasting as formatted JSON using optional target
class Comment < ActiveRecord::Base
  require 'activity_notification/optional_targets/action_cable_api_channel'
  acts_as_notifiable :admins, targets: [Admin.first].compact,
    optional_targets: {
      ActivityNotification::OptionalTarget::ActionCableApiChannel => { channel_prefix: 'admin_notification_api' }
    }
end
```

#### Amazon SNS as optional target

_activity_notification_ provides **ActivityNotification::OptionalTarget::AmazonSNS** as default optional target implementation for Amazon SNS.

First, add **aws-sdk** or **aws-sdk-sns** (>= AWS SDK for Ruby v3) gem to your Gemfile and set AWS Credentials for SDK (See [Configuring the AWS SDK for Ruby](https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/setup-config.html)).

```ruby
gem 'aws-sdk', '~> 2'
# --- or ---
gem 'aws-sdk-sns', '~> 1'
```

```ruby
require 'aws-sdk'
# --- or ---
require 'aws-sdk-sns'

Aws.config.update(
  region: 'your_region',
  credentials: Aws::Credentials.new('your_access_key_id', 'your_secret_access_key')
)
```

Then, write `require 'activity_notification/optional_targets/amazon_sns'` statement in your notifiable model and set _ActivityNotification::OptionalTarget::AmazonSNS_ to _acts_as_notifiable_ with _:topic_arn_, _:target_arn_ or _:phone_number_ initializing parameters.
Any other options for `Aws::SNS::Client.new` are available as initializing parameters. See [API Reference of Class: Aws::SNS::Client](http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/SNS/Client.html) for more details.

```ruby
class Comment < ActiveRecord::Base
  require 'activity_notification/optional_targets/amazon_sns'
  acts_as_notifiable :admins, targets: [Admin.first].compact,
    optional_targets: {
      ActivityNotification::OptionalTarget::AmazonSNS => { topic_arn: 'arn:aws:sns:XXXXX:XXXXXXXXXXXX:XXXXX' }
    }
end
```

#### Slack as optional target

_activity_notification_ provides **ActivityNotification::OptionalTarget::Slack** as default optional target implementation for Slack.

First, add **slack-notifier** gem to your Gemfile and create Incoming WebHooks in Slack (See [Incoming WebHooks](https://wemakejp.slack.com/apps/A0F7XDUAZ-incoming-webhooks)).

```ruby
gem 'slack-notifier'
```

Then, write `require 'activity_notification/optional_targets/slack'` statement in your notifiable model and set _ActivityNotification::OptionalTarget::Slack_ to _acts_as_notifiable_ with _:webhook_url_ and _:target_username_ initializing parameters. _:webhook_url_ is created WebHook URL and required, _:target_username_ is target's slack user name as String value, symbol method name or lambda function and is optional.
Any other options for `Slack::Notifier.new` are available as initializing parameters. See [Github slack-notifier](https://github.com/stevenosloan/slack-notifier) and [API Reference of Class: Slack::Notifier](http://www.rubydoc.info/gems/slack-notifier/1.5.1/Slack/Notifier) for more details.

```ruby
class Comment < ActiveRecord::Base
  require 'activity_notification/optional_targets/slack'
  acts_as_notifiable :admins, targets: [Admin.first].compact,
    optional_targets: {
      ActivityNotification::OptionalTarget::Slack  => {
        webhook_url: 'https://hooks.slack.com/services/XXXXXXXXX/XXXXXXXXX/XXXXXXXXXXXXXXXXXXXXXXXX',
        target_username: :slack_username, channel: 'activity_notification', username: 'ActivityNotification', icon_emoji: ":ghost:"
      }
    }
end
```

#### Developing custom optional targets

You can develop any custom optional targets.
Custom optional target class must extend **ActivityNotification::OptionalTarget::Base** and override **initialize_target** and **notify** method.
You can use **render_notification_message** method to prepare message from notification instance using view template.

For example, create _lib/custom_optional_targets/amazon_sns.rb_ as follows:

```ruby
module CustomOptionalTarget
  # Custom optional target implementation for mobile push notification or SMS using Amazon SNS.
  class AmazonSNS < ActivityNotification::OptionalTarget::Base
    require 'aws-sdk'

    # Initialize method to prepare Aws::SNS::Client
    def initialize_target(options = {})
      @topic_arn    = options.delete(:topic_arn)
      @target_arn   = options.delete(:target_arn)
      @phone_number = options.delete(:phone_number)
      @sns_client = Aws::SNS::Client.new(options)
    end

    # Publishes notification message to Amazon SNS
    def notify(notification, options = {})
      @sns_client.publish(
        topic_arn:    notification.target.resolve_value(options.delete(:topic_arn) || @topic_arn),
        target_arn:   notification.target.resolve_value(options.delete(:target_arn) || @target_arn),
        phone_number: notification.target.resolve_value(options.delete(:phone_number) || @phone_number),
        message: render_notification_message(notification, options)
      )
    end
  end
end
```

Then, you can configure them to notifiable model by _acts_as_notifiable_ like this:

```ruby
class Comment < ActiveRecord::Base
  require 'custom_optional_targets/amazon_sns'
  acts_as_notifiable :admins, targets: [Admin.first].compact,
    optional_targets: {
      CustomOptionalTarget::AmazonSNS => { topic_arn: 'arn:aws:sns:XXXXX:XXXXXXXXXXXX:XXXXX' }
    }
end
```

_acts_as_notifiable_ creates optional target instances and calls _initialize_target_ method with initializing parameters.

#### Subscription management of optional targets

_ActivityNotification::Subscription_ model provides API to subscribe and unsubscribe optional notification targets. Call these methods with optional target name like this:

```ruby
# Subscribe Acltion Cable channel for 'comment.reply' notifications
user.find_or_create_notification_subscription('comment.reply').subscribe_to_optional_target(:action_cable_channel)

# Subscribe Acltion Cable API channel for 'comment.reply' notifications
user.find_or_create_notification_subscription('comment.reply').subscribe_to_optional_target(:action_cable_api_channel)

# Unsubscribe Slack notification for 'comment.reply' notifications
user.find_or_create_notification_subscription('comment.reply').unsubscribe_to_optional_target(:slack)
```

You can also manage subscriptions of optional targets by subscriptions REST API. See [REST API backend](#rest-api-backend) for more details.

You can see sample subscription management view in demo application here: *https://activity-notification-example.herokuapp.com/users/1/subscriptions*

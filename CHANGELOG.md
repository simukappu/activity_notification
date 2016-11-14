## 1.0.2 / 2016-11-14
[Full Changelog](http://github.com/simukappu/activity_notification/compare/v1.0.1...v1.0.2)

Bug Fixes:

* Fix migration and notification generator's path

## 1.0.1 / 2016-11-05
[Full Changelog](http://github.com/simukappu/activity_notification/compare/v1.0.0...v1.0.1)

Enhancements:

* Add function of batch email notification
  * Batch mailer API
  * Default batch notification email templates
  * Target role configuration for batch email notification
* Improve target API
  * Add `:reverse`, `:with_group_members`, `:as_latest_group_member` and `:custom_filter` options to API loading notification index
  * Add methods to get notifications for specified target type grouped by targets like `notification_index_map`
* Arrange default notification email view templates

## 1.0.0 / 2016-10-06
[Full Changelog](http://github.com/simukappu/activity_notification/compare/v0.0.10...v1.0.0)

Enhancements:

* Improve notification API
  * Add methods to count distinct group members or notifiers like `group_member_notifier_count`
  * Update `send_later` argument of `send_notification_email` method to options hash argument
* Improve target API
  * Update `notification_index` API to automatically load opened notifications with unopend notifications
* Improve acts_as roles
  * Add `acts_as_group` role
  * Add `printable_name` configuration for all roles
  * Add `:dependent_notifications` option to `acts_as_notifiable` to make handle notifications with deleted notifiables
* Arrange default notification view templates
* Arrange bundled test application
* Make default rails version 5.0 and update gem dependency

Breaking change:
* Rename `opened_limit` configuration parameter to `opened_index_limit`
  * http://github.com/simukappu/activity_notification/commit/591e53cd8977220f819c11cd702503fc72dd1fd1

## 0.0.10 / 2016-09-11
[Full Changelog](http://github.com/simukappu/activity_notification/compare/v0.0.9...v0.0.10)

Enhancements:

* Improve controller action and notification API
  * Add filter options to `open_all` action and `open_all_of` method
* Add source documentation with YARD
* Support rails 5.0 and update gem dependency

Bug Fixes:

* Fix `Notification#notifiable_path` method to be called with key
* Add including `PolymorphicHelpers` statement to `seed.rb` in test application to resolve String extention

## 0.0.9 / 2016-08-19
[Full Changelog](http://github.com/simukappu/activity_notification/compare/v0.0.8...v0.0.9)

Enhancements:

* Improve acts_as roles
  * Enable models to be configured by acts_as role without including statement
  * Disable email notification as default and add email configurations to acts_as roles
  * Remove `:skip_email` option from `acts_as_target`
* Update `Renderable#text` method to use `#{key}.text` field in i18n properties
  
Bug Fixes:

* Fix wrong method name of `Notification#notifiable_path`

## 0.0.8 / 2016-07-31
* First release
class Comment < ActiveRecord::Base
  belongs_to :article
  belongs_to :user
  validates :article, presence: true
  validates :user, presence: true

  acts_as_notifiable :users,
    targets: ->(comment, key) { ([comment.article.user] + comment.article.commented_users.to_a - [comment.user]).uniq },
    group: :article, notifier: :user, email_allowed: true,
    parameters: { test_default_param: '1' },
    notifiable_path: :article_notifiable_path,
    printable_name: ->(comment) { "comment \"#{comment.body}\"" },
    dependent_notifications: :update_group_and_delete_all

  # require 'activity_notification/optional_targets/amazon_sns'
  # require 'activity_notification/optional_targets/slack'
  require 'custom_optional_targets/console_output'
  acts_as_notifiable :admins, targets: Admin.all,
    group: :article, notifier: :user, notifiable_path: :article_notifiable_path,
    printable_name: ->(comment) { "comment \"#{comment.body}\"" }, dependent_notifications: :delete_all,
    optional_targets: {
      # ActivityNotification::OptionalTarget::AmazonSNS => { topic_arn: 'arn:aws:sns:XXXXX:XXXXXXXXXXXX:XXXXX' },
      # # ActivityNotification::OptionalTarget::AmazonSNS => { phone_number: :phone_number },
      # ActivityNotification::OptionalTarget::Slack  => {
        # webhook_url: 'https://hooks.slack.com/services/XXXXXXXXX/XXXXXXXXX/XXXXXXXXXXXXXXXXXXXXXXXX',
        # slack_name: :slack_name, channel: 'activity_notification', username: 'ActivityNotification', icon_emoji: ":ghost:"
      # },
      CustomOptionalTarget::ConsoleOutput => {}
    }

  def article_notifiable_path
    article_path(article)
  end

  def author?(user)
    self.user == user
  end
end

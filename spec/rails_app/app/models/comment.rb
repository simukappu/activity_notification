class Comment < ActiveRecord::Base
  belongs_to :article
  belongs_to :user

  include ActivityNotification::Notifiable
  acts_as_notifiable :users,
    targets: ->(comment, key) { (comment.article.commented_users.to_a - [comment.user] + [comment.article.user]).uniq },
    group: :article,
    notifier: :user,
    email_allowed: :custom_notification_email_to_users_allowed?,
    parameters: {test_default_param: '1'}#,
    #notifiable_path: :custom_notifiable_path

  def custom_notification_email_to_users_allowed?(user, key)
    true
  end

end

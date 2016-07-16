class Comment < ActiveRecord::Base
  belongs_to :article
  belongs_to :user

  include ActivityNotification::Notifiable
  acts_as_notifiable :users,
    targets: :custom_notification_users,
    group: :article,
    notifier: :user,
    email_allowed: :custom_notification_email_to_users_allowed?#,
    #notifiable_path: :custom_notifiable_path

  def custom_notification_users(key)
    User.where(id: self.article.comments.pluck(:user_id))
  end

  def custom_notification_email_to_users_allowed?(user, key)
    true
  end

end

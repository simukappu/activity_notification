class Article < ActiveRecord::Base
  belongs_to :user
  has_many :comments, dependent: :destroy
  has_many :commented_users, through: :comments, source: :user
  validates :user, presence: true

  acts_as_notifiable :users,
    targets: ->(article, key) { User.all.to_a - [article.user] },
    notifier: :user,
    email_allowed: true,
    printable_name: ->(article) { "new article \"#{article.title}\"" }
  acts_as_notification_group printable_name: ->(article) { "article \"#{article.title}\"" }

  def author?(user)
    self.user == user
  end
end

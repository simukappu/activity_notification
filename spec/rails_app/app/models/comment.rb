class Comment < ActiveRecord::Base
  belongs_to :article
  belongs_to :user
  validates :article, presence: true
  validates :user, presence: true

  acts_as_notifiable :users,
    targets: ->(comment, key) {
      ([comment.article.user] + comment.article.commented_users.to_a - [comment.user]).uniq
    },
    group: :article,
    notifier: :user,
    email_allowed: true,
    parameters: { test_default_param: '1' },
    notifiable_path: :article_notifiable_path,
    printable_name: ->(comment) { "comment \"#{comment.body}\"" }

  def article_notifiable_path
    article_path(article)
  end
end

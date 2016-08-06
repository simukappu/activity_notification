class Article < ActiveRecord::Base
  belongs_to :user
  has_many :comments, dependent: :delete_all
  has_many :commented_users, through: :comments, source: :user
  validates :user, presence: true

  acts_as_notifiable :users,
    targets: ->(article, key) { User.all.to_a - [article.user] },
    notifier: :user,
    email_allowed: true#, 
    #notifiable_path: ->(article) { concept_issue_path(issue.concept, issue) }
end

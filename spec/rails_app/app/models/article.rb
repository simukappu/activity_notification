class Article < ActiveRecord::Base
  acts_as_notifiable :users,
    targets: ->(article, key) { [article.user] },
    notifier: :user,
    email_allowed: true#, 
    #notifiable_path: ->(article) { concept_issue_path(issue.concept, issue) }

  belongs_to :user
  has_many :comments, dependent: :delete_all
  has_many :commented_users, through: :comments, source: :user
end

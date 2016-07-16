class Article < ActiveRecord::Base
  include ActivityNotification::Notifiable
  acts_as_notifiable :users,
    targets: ->(issue, key) {
      [user]
    },
    notifier: :user,
    email_allowed: ->(article, target_user, key) {
      true
    }#, 
    #notifiable_path: ->(article) { concept_issue_path(issue.concept, issue) }

  belongs_to :user
  has_many :comments, dependent: :delete_all
end

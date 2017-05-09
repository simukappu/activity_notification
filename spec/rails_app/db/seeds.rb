# coding: utf-8
# This file is seed file for test data on development environment.

def clear_database
  [ActivityNotification::Notification, ActivityNotification::Subscription, Comment, Article, Admin, User].each do |model|
    model.delete_all
  end
end

def reset_pk_sequence
  models = [Comment, Article, Admin, User]
  if ActivityNotification.config.orm == :active_record
    models.concat([ActivityNotification::Notification, ActivityNotification::Subscription])
  end
  case ENV['AN_TEST_DB']
  when nil, '', 'sqlite'
    ActiveRecord::Base.connection.execute("UPDATE sqlite_sequence SET seq = 0")
  when 'mysql'
    models.each do |model|
      ActiveRecord::Base.connection.execute("ALTER TABLE #{model.table_name} AUTO_INCREMENT = 1")
    end
  when 'postgresql'
    models.each do |model|
      ActiveRecord::Base.connection.reset_pk_sequence!(model.table_name)
    end
  when 'mongodb'
  else
    raise "#{ENV['AN_TEST_DB']} as AN_TEST_DB environment variable is not supported"
  end
end

clear_database
reset_pk_sequence

['Ichiro', 'Stephen', 'Klay', 'Kevin'].each do |name|
  user = User.new(
    email:                 "#{name.downcase}@example.com",
    password:              'changeit',
    password_confirmation: 'changeit',
    name:                  name,
  )
  user.skip_confirmation!
  user.save!
end

['Ichiro'].each do |name|
  user = User.find_by(name: name)
  Admin.create(
    user: user,
    phone_number: ENV['OPTIONAL_TARGET_AMAZON_SNS_PHONE_NUMBER'],
    slack_username: ENV['OPTIONAL_TARGET_SLACK_USERNAME']
  )
end

User.all.each do |user|
  article = user.articles.create(
    title: "#{user.name}'s first article",
    body:  "This is the first #{user.name}'s article. Please read it!"
  )
  article.notify :users, send_email: false
end

Article.all.each do |article|
  User.all.each do |user|
    comment = article.comments.create(
      user: user,
      body:  "This is the first #{user.name}'s comment to #{article.user.name}'s article."
    )
    comment.notify :users, send_email: false
  end
end
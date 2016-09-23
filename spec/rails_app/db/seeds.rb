# coding: utf-8
# This file is seed file for test data on development environment.

ActivityNotification::Notification.delete_all
Comment.delete_all
Article.delete_all
Admin.delete_all
User.delete_all
User.connection.execute("UPDATE sqlite_sequence SET seq = 0;")

['ichiro', 'stephen', 'klay', 'kevin'].each do |name|
  user = User.new(
    email:                 "#{name}@example.com",
    password:              'changeit',
    password_confirmation: 'changeit',
    name:                  name,
  )
  user.skip_confirmation!
  user.save!
end

['ichiro'].each do |name|
  user = User.find_by_name(name)
  Admin.create(user: user)
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
Rails.application.routes.draw do
  notify_to :users

  resources :articles
end

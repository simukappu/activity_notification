Rails.application.routes.draw do
  root to: 'articles#index'
  devise_for :users
  resources :articles
  resources :comments, only: [:create, :destroy]

  notify_to :users, with_subscription: true
  notify_to :admins, with_devise: :users, with_subscription: true
end

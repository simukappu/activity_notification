Rails.application.routes.draw do
  root to: 'articles#index'
  devise_for :users
  resources :articles
  resources :comments, only: [:create, :destroy]

  notify_to :users
  notify_to :admins
end

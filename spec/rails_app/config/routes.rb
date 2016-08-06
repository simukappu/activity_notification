Rails.application.routes.draw do
  devise_for :users
  resources :articles

  notify_to :users
end

Rails.application.routes.draw do
  root to: 'articles#index'
  devise_for :users
  resources :articles, except: [:destroy]
  resources :comments, only: [:create, :destroy]

  notify_to :users, with_subscription: true
  notify_to :users, with_devise: :users, devise_default_routes: true, with_subscription: true

  scope :api do
    scope :"v#{ActivityNotification::GEM_VERSION::MAJOR}" do
      notify_to :users, api_mode: true, with_subscription: true
      #TODO
      # notify_to :users, api_mode: true, with_devise: :users, devise_default_routes: true, with_subscription: true
      resources :apidocs, only: [:index], controller: 'activity_notification/apidocs'
    end
  end

  notify_to :admins, with_devise: :users, with_subscription: true
  scope :admins, as: :admins do
    notify_to :admins, with_devise: :users, devise_default_routes: true, with_subscription: true, routing_scope: :admins
  end
end

Rails.application.routes.draw do
  root to: 'articles#index'
  devise_for :users
  resources :articles, except: [:destroy]
  resources :comments, only: [:create, :destroy]

  notify_to :users, with_subscription: true
  notify_to :users, with_devise: :users, devise_default_routes: true, with_subscription: true

  namespace :api do
    scope :"v#{ActivityNotification::GEM_VERSION::MAJOR}" do
      mount_devise_token_auth_for 'User', at: 'auth'
    end
  end
  scope :api do
    scope :"v#{ActivityNotification::GEM_VERSION::MAJOR}" do
      notify_to :users, api_mode: true, with_subscription: true
      notify_to :users, api_mode: true, with_devise: :users, devise_default_routes: true, with_subscription: true
      resources :apidocs, only: [:index], controller: 'activity_notification/apidocs'
    end
  end

  notify_to :admins, with_devise: :users, with_subscription: true
  scope :admins, as: :admins do
    notify_to :admins, with_devise: :users, devise_default_routes: true, with_subscription: true, routing_scope: :admins
  end

  scope :api do
    scope :"v#{ActivityNotification::GEM_VERSION::MAJOR}" do
      notify_to :admins, api_mode: true, with_devise: :users, with_subscription: true
      scope :admins, as: :admins do
        notify_to :admins, api_mode: true, with_devise: :users, devise_default_routes: true, with_subscription: true
      end
    end
  end
end

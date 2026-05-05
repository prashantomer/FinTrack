Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      post "auth/login",  to: "auth#login"
      get  "auth/me",     to: "auth#me"
      put  "auth/me",     to: "auth#update_me"

      resources :banks,     only: [ :index, :show ]
      resources :platforms, only: [ :index, :show ]

      resources :accounts do
        member do
          post :close
          get "audit-logs", to: "accounts#audit_logs"
        end
      end

      resources :platform_accounts, path: "platform-accounts"

      resources :transactions, only: [ :index, :create ]

      resources :instruments do
        collection do
          get :types
          get :tracked
          get "user-instruments", to: "instruments#user_instruments"
        end
        member do
          post   :track
          delete :untrack
        end
      end

      resources :term_accounts, path: "term-accounts", only: [ :index, :show, :create ] do
        member do
          post :close
          get "audit-logs", to: "term_accounts#audit_logs"
        end
      end

      resources :investments

      resources :follios

      resources :imports, only: [ :index, :create, :show ] do
        collection { get "template/:import_type", to: "imports#template", as: :template }
      end

      scope :reports do
        get    :dashboard,              to: "reports#dashboard"
        post   "dashboard/refresh",     to: "reports#refresh_dashboard"
        get    "dashboard/cache-status", to: "reports#dashboard_cache_status"
        get    "spending-trends",       to: "reports#spending_trends"
        get    "investment-summary",    to: "reports#investment_summary"
        get    :portfolio,              to: "reports#portfolio"
      end

      post "errors", to: "client_errors#create"
    end
  end
end

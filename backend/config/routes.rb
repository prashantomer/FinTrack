require "sidekiq/web"

# Sidekiq Web UI — HTTP basic auth gated. Set SIDEKIQ_USERNAME and
# SIDEKIQ_PASSWORD in `.env`; without them the UI is disabled (returns 404).
Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
  expected_user = ENV["SIDEKIQ_USERNAME"].to_s
  expected_pass = ENV["SIDEKIQ_PASSWORD"].to_s
  next false if expected_user.empty? || expected_pass.empty?
  ActiveSupport::SecurityUtils.secure_compare(username, expected_user) &
    ActiveSupport::SecurityUtils.secure_compare(password, expected_pass)
end if defined?(Sidekiq::Web)

Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  # Sidekiq dashboard. Only mounted when both env vars are set, so a
  # misconfigured deployment doesn't accidentally expose the UI publicly.
  if ENV["SIDEKIQ_USERNAME"].present? && ENV["SIDEKIQ_PASSWORD"].present?
    mount Sidekiq::Web => "/sidekiq"
  end

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

      resources :transactions, only: [ :index, :create, :update ]

      resources :instruments do
        collection do
          get :types
          get :tracked
          get "user-instruments", to: "instruments#user_instruments"
        end
        member do
          post   :track
          delete :untrack
          get :position
          get :lots
          get "transactions",   to: "instruments#linked_transactions"
          get "price-history",  to: "instruments#price_history"
        end
      end

      resources :term_accounts, path: "term-accounts", only: [ :index, :show, :create ] do
        member do
          post :close
          get "audit-logs", to: "term_accounts#audit_logs"
        end
      end

      resources :investments, only: [ :index, :show, :create, :update ] do
        collection do
          patch :folio, action: :update_folio
        end
      end

      resources :holdings do
        collection { post :refresh }
      end

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
        get    :performance,            to: "reports#performance"
      end

      post "errors", to: "client_errors#create"

      namespace :assistant do
        resource :setting, only: [ :show, :update ]
        post "setting/test", to: "settings#test"

        resources :messages, only: [ :index, :create ] do
          collection { delete :all, to: "messages#destroy_all" }
          member do
            post   :pin
            delete :pin, action: :unpin
          end
        end
        resources :attachments, only: [ :create, :show ]
        post :sessions, to: "sessions#create"
      end
    end
  end
end

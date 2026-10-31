# MCP over Streamable HTTP with Token Authentication. StreamableHTTPTransport is a Rack app,
# wrapped with AuthenticatedMcpApp to enforce user scoping (?token=...).
require_relative "../app/mcp/authenticated_mcp_app"

DocnotateServerTransport = AuthenticatedMcpApp.new(
  MCP::Server::Transports::StreamableHTTPTransport.new(
    DocnotateServer,
    stateless: true,
    dns_rebinding_protection: false
  )
)

Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "home#index"

  post "settings/editor", to: "settings#update_editor", as: :settings_editor
  resource :workspace, only: [:update, :create]

  # MCP endpoint for coding agents (token authenticated)
  mount DocnotateServerTransport => "/mcp", as: :mcp

  resource :filesystem, only: [:show], controller: "filesystem" do
    get :nodes
  end

  resources :documents, only: [:index, :show, :update, :destroy, :create] do
    collection do
      get :open
    end
    member do
      post :open_in_editor
    end
    get "content", to: "document_contents#show", as: :content, format: false
    get "content/*path", to: "document_contents#asset", as: :content_asset, format: false
    resources :comments, only: [:create, :destroy, :update] do
      resource :resolver, only: [:update], controller: "resolver", module: :comments
    end
    resource :version_resolver, only: [:update], controller: "version_resolver", module: :comments
  end
end

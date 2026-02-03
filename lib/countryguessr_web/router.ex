defmodule CountryguessrWeb.Router do
  use Phoenix.Router

  import Phoenix.Controller

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Health check - no pipeline needed
  get "/health", CountryguessrWeb.HealthController, :index

  # API routes
  scope "/api", CountryguessrWeb do
    pipe_through :api

    get "/games/:id", GameController, :show
    post "/games/:id/increment", GameController, :increment
    post "/games/:id/decrement", GameController, :decrement
    post "/games/:id/reset", GameController, :reset
  end
end

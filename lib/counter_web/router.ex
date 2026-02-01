defmodule CounterWeb.Router do
  use Phoenix.Router

  import Phoenix.Controller

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Health check - no pipeline needed
  get "/health", CounterWeb.HealthController, :index

  # API routes
  scope "/api", CounterWeb do
    pipe_through :api

    get "/counters/:id", CounterController, :show
    post "/counters/:id/increment", CounterController, :increment
    post "/counters/:id/decrement", CounterController, :decrement
    post "/counters/:id/reset", CounterController, :reset
  end
end

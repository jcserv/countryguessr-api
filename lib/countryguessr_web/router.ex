defmodule CountryguessrWeb.Router do
  use Phoenix.Router

  import Phoenix.Controller

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Health check - no pipeline needed
  get "/health", CountryguessrWeb.HealthController, :index
end

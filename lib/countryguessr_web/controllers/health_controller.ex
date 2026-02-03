defmodule CountryguessrWeb.HealthController do
  use Phoenix.Controller, formats: [:json]

  @doc """
  Health check endpoint.

  Returns 200 OK with status info.
  Used by load balancers and orchestrators (Fly.io, K8s, etc.)
  """
  def index(conn, _params) do
    json(conn, %{
      status: "ok",
      timestamp: DateTime.utc_now()
    })
  end
end

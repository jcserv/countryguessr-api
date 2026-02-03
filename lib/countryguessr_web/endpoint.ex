defmodule CountryguessrWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :countryguessr

  # WebSocket for Phoenix Channels
  socket "/socket", CountryguessrWeb.UserSocket,
    websocket: true,
    longpoll: false

  # Request ID for tracing
  plug Plug.RequestId

  # Parse JSON bodies
  plug Plug.Parsers,
    parsers: [:json],
    pass: ["*/*"],
    json_decoder: Jason

  # Logging
  plug Plug.Logger

  # CORS - configure allowed origins in config
  plug CORSPlug

  # Rate limiting - protect against abuse
  plug CountryguessrWeb.Plugs.RateLimiter

  # Route to router
  plug CountryguessrWeb.Router
end

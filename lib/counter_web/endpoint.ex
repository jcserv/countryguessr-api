defmodule CounterWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :counter

  # WebSocket for Phoenix Channels
  socket "/socket", CounterWeb.UserSocket,
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

  # Route to router
  plug CounterWeb.Router
end

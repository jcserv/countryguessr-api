import Config

# Runtime configuration for production
# This file is executed at runtime, not compile time

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  # CORS and WebSocket origins in production
  allowed_origins =
    case System.get_env("CORS_ORIGINS") do
      nil -> ["https://#{host}"]
      origins -> String.split(origins, ",")
    end

  config :countryguessr, CountryguessrWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    check_origin: allowed_origins

  config :cors_plug,
    origin: allowed_origins,
    max_age: 86400,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]

  # Fly.io clustering configuration
  if app_name = System.get_env("FLY_APP_NAME") do
    config :dns_cluster,
      query: "#{app_name}.internal",
      interval: 5_000
  end
end

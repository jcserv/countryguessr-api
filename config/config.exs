# General application configuration
import Config

config :countryguessr,
  generators: [timestamp_type: :utc_datetime]

# Endpoint configuration
config :countryguessr, CountryguessrWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: CountryguessrWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Countryguessr.PubSub,
  live_view: [signing_salt: "dev_salt"]

# JSON library
config :phoenix, :json_library, Jason

# Rate limiting
config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60, cleanup_interval_ms: 60_000]}

# Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :game_id]

# Import environment specific config
import_config "#{config_env()}.exs"

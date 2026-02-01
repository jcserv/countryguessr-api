# General application configuration
import Config

config :counter,
  generators: [timestamp_type: :utc_datetime]

# Endpoint configuration
config :counter, CounterWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: CounterWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Counter.PubSub,
  live_view: [signing_salt: "dev_salt"]

# JSON library
config :phoenix, :json_library, Jason

# Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :counter_id]

# Import environment specific config
import_config "#{config_env()}.exs"

import Config

# Production config - most settings come from runtime.exs
config :countryguessr, CountryguessrWeb.Endpoint,
  server: true

# Production logging
config :logger, level: :info

# Runtime production configuration is in config/runtime.exs

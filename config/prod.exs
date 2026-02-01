import Config

# Production config - most settings come from runtime.exs
config :counter, CounterWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true

# Production logging
config :logger, level: :info

# Runtime production configuration is in config/runtime.exs

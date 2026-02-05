# 🎯 countryguessr-api

a realtime Phoenix API for multiplayer countryguessr games.

## features

- 🕹️ in-memory game rooms managed by a GenServer
- 🔌 realtime updates over Phoenix Channels (`game:{id}`)
- 🧭 country code validation aligned with the frontend geojson
- 🚦 basic rate limiting on gameplay actions
- ❤️ health endpoint for deploy checks

## dependencies

- [phoenix](https://www.phoenixframework.org/)
- [bandit](https://github.com/mtrudel/bandit)
- [phoenix pubsub](https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html)
- [jason](https://github.com/michalmuskala/jason)
- [cors_plug](https://github.com/mschae/cors_plug)
- [hammer](https://github.com/ExHammer/hammer)
- [dns_cluster](https://github.com/phoenixframework/dns_cluster)

## references

- [phoenix channels guide](https://hexdocs.pm/phoenix/channels.html)
- [fly.io](https://fly.io/)

# Elixir API Template

Barebones Phoenix API template demonstrating core Elixir/OTP patterns.

## Patterns Demonstrated

- **GenServer** - Stateful process (`lib/counter/counter_server.ex`)
- **Phoenix Channels** - Real-time WebSocket (`lib/counter_web/channels/`)
- **Transport-agnostic contexts** - Same logic for HTTP and WebSocket (`lib/counter/counter.ex`)
- **Supervision trees** - Registry + DynamicSupervisor (`lib/counter/application.ex`)
- **Fly.io deployment** - Dockerfile + clustering config

## Example: Shared Counter

Multiple clients can connect and increment/view a counter in real-time.

```
┌─────────┐    HTTP     ┌──────────────┐
│ Client  │────────────▶│              │
└─────────┘             │   Counter    │ ◀──▶ CounterServer (GenServer)
                        │   Context    │
┌─────────┐  WebSocket  │              │
│ Client  │────────────▶│              │
└─────────┘             └──────────────┘
```

## Quick Start

```bash
# Install dependencies
mix deps.get

# Start development server
iex -S mix phx.server
```

## API

### HTTP Endpoints

```bash
# Health check
curl localhost:4000/health

# Get counter value
curl localhost:4000/api/counters/my-counter

# Increment
curl -X POST localhost:4000/api/counters/my-counter/increment

# Reset
curl -X POST localhost:4000/api/counters/my-counter/reset
```

### WebSocket

Connect to `ws://localhost:4000/socket/websocket`

```javascript
// Using Phoenix.js client
const socket = new Socket("/socket", { params: { player_id: "uuid" } });
socket.connect();

const channel = socket.channel("counter:my-counter", {});
channel.join();

// Increment
channel.push("increment", {}).receive("ok", ({ value }) => console.log(value));

// Listen for updates
channel.on("updated", ({ value }) => console.log("Counter:", value));
```

## Project Structure

```
lib/
├── counter/                    # Core logic (transport-agnostic)
│   ├── application.ex          # Supervision tree
│   ├── counter.ex              # Context API
│   └── counter_server.ex       # GenServer
│
└── counter_web/                # Web layer
    ├── endpoint.ex
    ├── router.ex
    ├── controllers/            # HTTP
    └── channels/               # WebSocket
```

## Commands

```bash
make dev          # Start dev server
make test         # Run tests
make format       # Format code
make lint         # Run Credo
make docker.build # Build Docker image
make docker.run   # Run container
```

## Deploy to Fly.io

```bash
fly launch        # Initialize (first time)
fly deploy        # Deploy
fly logs          # View logs
```

## Adding New Features

### New HTTP Endpoint

1. Add route in `lib/counter_web/router.ex`
2. Create controller in `lib/counter_web/controllers/`
3. Call context functions (not business logic in controller)

### New WebSocket Event

1. Add handler in channel (`handle_in/3`)
2. Call context functions
3. Broadcast updates via PubSub

### New Context

1. Create module in `lib/counter/` with public API
2. Create GenServer if stateful
3. Add to supervision tree in `application.ex`
4. Call from HTTP controllers and/or channels

## License

GPL-3.0

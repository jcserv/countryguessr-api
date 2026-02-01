# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Elixir/Phoenix API for CountryGuessr competitive mode. Players race to claim countries in real-time multiplayer sessions. Uses OTP patterns (GenServer, Registry, DynamicSupervisor) for game state management and WebSocket for real-time updates.

**Related frontend**: `~/Developer/countryguessr` (React 19 + TypeScript)

## Game Rules

- 178 countries available to claim (ISO_A2 codes from GeoJSON)
- Players join a lobby, host starts the game
- Once a country is claimed, no other player can claim it
- Game ends when: all countries claimed OR time limit reached
- Winner: player with most claimed countries

## Common Commands

```bash
make setup        # Install dependencies
make dev          # Start development server (iex -S mix phx.server)
make test         # Run all tests
make lint         # Run Credo linter (mix credo --strict)
make format       # Format code
make ci           # Run all CI checks (deps, compile, format, lint, test)
```

Run a single test file:
```bash
mix test test/countryguessr/game_test.exs
```

Run a specific test by line number:
```bash
mix test test/countryguessr/game_test.exs:10
```

## Architecture

### Two-Layer Design

1. **Core Context (`lib/countryguessr/`)** - Transport-agnostic game logic
   - `game.ex` - Public API (create, join, start, claim_country, get_state)
   - `game_server.ex` - GenServer process per game session
   - `application.ex` - OTP supervision tree with Registry + DynamicSupervisor

2. **Web Layer (`lib/countryguessr_web/`)** - HTTP and WebSocket interfaces
   - Both transports call the same Game context functions
   - PubSub broadcasts propagate updates to all players in a game

### OTP Supervision Tree

```
Application
├── Registry (process lookup by game_id)
├── DynamicSupervisor (spawns GameServer processes on demand)
├── Phoenix.PubSub (broadcasts game updates)
└── Endpoint (HTTP/WebSocket)
```

### Game State Structure

```elixir
%{
  game_id: String.t(),
  status: :lobby | :playing | :finished,
  host_id: String.t(),
  players: %{player_id => %{name: String.t(), claimed: [String.t()]}},
  claimed_countries: %{country_code => player_id},
  time_limit: integer(),      # seconds
  started_at: DateTime.t() | nil
}
```

### API Routes

```
GET  /health                           → Health check
POST /api/games                        → Create new game (returns game_id, join code)
GET  /api/games/:id                    → Get game state
POST /api/games/:id/join               → Join game (body: {player_id, name})
POST /api/games/:id/start              → Start game (host only)
POST /api/games/:id/claim              → Claim country (body: {player_id, country_code})
```

### WebSocket

- Connect to UserSocket with `player_id` param
- Join topic `game:{game_id}`
- **Client events**: `"join"`, `"start"`, `"claim"`
- **Server broadcasts**:
  - `"player_joined"` - New player entered lobby
  - `"game_started"` - Game has begun
  - `"country_claimed"` - A country was claimed (includes who, which country)
  - `"game_ended"` - Game finished (includes final scores)

## Code Patterns

- **Pattern matching** in function heads for control flow
- **Type specs** (`@spec`) on all public functions
- **Registry pattern** for looking up game processes by ID
- **PubSub** for broadcasting state changes to all players
- Return tuples: `{:ok, value}` or `{:error, reason}`
- Error reasons: `:not_found`, `:already_claimed`, `:game_not_started`, `:not_host`

## Country Data

- 178 countries with ISO_A2 codes (e.g., "US", "FR", "JP")
- Country validation against known codes
- Frontend provides country names; API only tracks codes

## User Identity

- User IDs generated client-side (UUID stored in localStorage)
- Anonymous players - no authentication required
- Player names provided on join (display only)

## CI Requirements

All must pass:
1. Compile with `--warnings-as-errors`
2. Format check (`mix format --check-formatted`)
3. Credo strict mode
4. Tests

## Environment Variables

- `SECRET_KEY_BASE` - Required for Phoenix sessions
- `PHX_HOST` - Hostname (default: localhost)
- `PORT` - Server port (default: 4000)
- `CORS_ORIGINS` - Comma-separated allowed origins

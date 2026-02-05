defmodule Countryguessr.Game do
  @moduledoc """
  Game context - transport-agnostic business logic.

  This module provides the public API for game operations.
  It can be called from HTTP controllers, WebSocket channels,
  or any future transport layer.

  ## Competitive Mode Example

      # Join a game
      Countryguessr.Game.join("room-ABC123", "player-1", "Alice")
      #=> {:ok, %{game_id: "room-ABC123", status: :lobby, ...}}

      # Start the game (host only)
      Countryguessr.Game.start_game("room-ABC123", "player-1")
      #=> {:ok, %{game_id: "room-ABC123", status: :playing, ...}}

      # Claim a country
      Countryguessr.Game.claim_country("room-ABC123", "player-1", "US")
      #=> {:ok, %{success: true}}

  ## Legacy Counter Example

      Countryguessr.Game.increment("my-game")
      #=> {:ok, 1}
  """

  alias Countryguessr.GameServer

  # =============================================================================
  # Competitive Game API
  # =============================================================================

  @doc """
  Gets the full state of a game.
  Returns `{:ok, state}` or `{:error, :not_found}`.
  """
  def get_state(game_id) do
    case GameServer.whereis(game_id) do
      nil -> {:error, :not_found}
      pid -> {:ok, GameServer.get_state(pid)}
    end
  end

  @doc """
  Joins a player to a game. Creates the game if it doesn't exist.
  The first player to join becomes the host.

  Returns `{:ok, state}` or `{:error, reason}`.
  """
  def join(game_id, player_id, nickname) do
    pid = ensure_started(game_id)
    GameServer.join(pid, player_id, nickname)
  end

  @doc """
  Removes a player from a game (marks as disconnected).
  Returns `:ok` or `{:error, reason}`.
  """
  def leave(game_id, player_id) do
    case GameServer.whereis(game_id) do
      nil -> {:error, :not_found}
      pid -> GameServer.leave(pid, player_id)
    end
  end

  @doc """
  Starts the game. Only the host can start.
  Returns `{:ok, state}` or `{:error, reason}`.
  """
  def start_game(game_id, player_id) do
    case GameServer.whereis(game_id) do
      nil -> {:error, :not_found}
      pid -> GameServer.start_game(pid, player_id)
    end
  end

  @doc """
  Claims a country for a player.
  Returns `{:ok, %{success: true}}` or `{:error, reason}`.
  """
  def claim_country(game_id, player_id, country_code) do
    case GameServer.whereis(game_id) do
      nil -> {:error, :not_found}
      pid -> GameServer.claim_country(pid, player_id, country_code)
    end
  end

  # =============================================================================
  # Legacy Counter API (for backwards compatibility)
  # =============================================================================

  @doc """
  Gets the current value of a game.
  Returns `{:ok, value}` or `{:error, :not_found}`.
  """
  @spec get(String.t()) :: {:ok, integer()} | {:error, :not_found}
  def get(game_id) do
    case GameServer.whereis(game_id) do
      nil -> {:error, :not_found}
      pid -> {:ok, GameServer.get(pid)}
    end
  end

  @doc """
  Increments a game by 1. Creates the game if it doesn't exist.
  Returns `{:ok, new_value}`.
  """
  @spec increment(String.t()) :: {:ok, integer()}
  def increment(game_id) do
    pid = ensure_started(game_id)
    {:ok, GameServer.increment(pid)}
  end

  @doc """
  Decrements a game by 1. Creates the game if it doesn't exist.
  Returns `{:ok, new_value}`.
  """
  @spec decrement(String.t()) :: {:ok, integer()}
  def decrement(game_id) do
    pid = ensure_started(game_id)
    {:ok, GameServer.decrement(pid)}
  end

  @doc """
  Resets a game to 0. Creates the game if it doesn't exist.
  Returns `{:ok, 0}`.
  """
  @spec reset(String.t()) :: {:ok, integer()}
  def reset(game_id) do
    pid = ensure_started(game_id)
    {:ok, GameServer.reset(pid)}
  end

  # =============================================================================
  # PubSub
  # =============================================================================

  @doc """
  Subscribes the calling process to game updates.

  Updates are sent as tuples:
  - `{:game_updated, game_id, value}` - Legacy counter update
  - `{:player_joined, player_id, nickname, is_host}` - Player joined
  - `{:player_left, player_id}` - Player disconnected
  - `{:game_started, started_at}` - Game started
  - `{:country_claimed, player_id, country_code}` - Country claimed
  - `{:timer_tick, time_remaining}` - Timer update
  - `{:game_ended, ended_at, winner_id, rankings}` - Game ended
  """
  @spec subscribe(String.t()) :: :ok
  def subscribe(game_id) do
    Phoenix.PubSub.subscribe(Countryguessr.PubSub, "game:#{game_id}")
  end

  # =============================================================================
  # Private
  # =============================================================================

  # Ensures a game process exists, starting one if needed
  defp ensure_started(game_id) do
    case GameServer.whereis(game_id) do
      nil ->
        case DynamicSupervisor.start_child(
               Countryguessr.DynamicSupervisor,
               {GameServer, game_id: game_id}
             ) do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end

      pid ->
        pid
    end
  end
end

defmodule Countryguessr.Game do
  @moduledoc """
  Game context - transport-agnostic business logic.

  This module provides the public API for game operations.
  It can be called from HTTP controllers, WebSocket channels,
  or any future transport layer.

  ## Example

      # Get or create a game, then increment it
      Countryguessr.Game.increment("my-game")
      #=> {:ok, 1}

      Countryguessr.Game.get("my-game")
      #=> {:ok, 1}

      Countryguessr.Game.reset("my-game")
      #=> {:ok, 0}
  """

  alias Countryguessr.GameServer

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

  @doc """
  Subscribes the calling process to game updates.
  Updates are sent as `{:game_updated, game_id, value}`.
  """
  @spec subscribe(String.t()) :: :ok
  def subscribe(game_id) do
    Phoenix.PubSub.subscribe(Countryguessr.PubSub, "game:#{game_id}")
  end

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

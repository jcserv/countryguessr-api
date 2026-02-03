defmodule CountryguessrWeb.GameController do
  @moduledoc """
  HTTP controller for game operations.

  Demonstrates how HTTP transport calls the Game context.
  The same Game context is also called by WebSocket channels.
  """
  use Phoenix.Controller, formats: [:json]

  alias Countryguessr.Game

  @doc """
  GET /api/games/:id

  Returns the current value of a game.
  """
  def show(conn, %{"id" => id}) do
    case Game.get(id) do
      {:ok, value} ->
        json(conn, %{id: id, value: value})

      {:error, :not_found} ->
        # Game doesn't exist yet, return 0
        json(conn, %{id: id, value: 0})
    end
  end

  @doc """
  POST /api/games/:id/increment

  Increments the game and returns the new value.
  """
  def increment(conn, %{"id" => id}) do
    {:ok, value} = Game.increment(id)
    json(conn, %{id: id, value: value})
  end

  @doc """
  POST /api/games/:id/decrement

  Decrements the game and returns the new value.
  """
  def decrement(conn, %{"id" => id}) do
    {:ok, value} = Game.decrement(id)
    json(conn, %{id: id, value: value})
  end

  @doc """
  POST /api/games/:id/reset

  Resets the game to 0.
  """
  def reset(conn, %{"id" => id}) do
    {:ok, value} = Game.reset(id)
    json(conn, %{id: id, value: value})
  end
end

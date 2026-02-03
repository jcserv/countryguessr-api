defmodule CountryguessrWeb.GameChannel do
  use Phoenix.Channel

  @moduledoc """
  WebSocket channel for real-time game updates.

  Demonstrates how WebSocket transport calls the Game context.
  The same Game context is also called by HTTP controllers.

  ## Topic

  Join with topic `game:{id}` where `{id}` is the game ID.

  ## Events

  ### Client → Server

  - `"increment"` - Increment the game
  - `"decrement"` - Decrement the game
  - `"reset"` - Reset the game to 0

  ### Server → Client

  - `"state"` - Sent on join with current value
  - `"updated"` - Broadcast when game changes
  """

  alias Countryguessr.Game

  require Logger

  @impl true
  def join("game:" <> game_id, _params, socket) do
    # Subscribe to game updates via PubSub
    Game.subscribe(game_id)

    # Get current value (or 0 if game doesn't exist)
    value =
      case Game.get(game_id) do
        {:ok, v} -> v
        {:error, :not_found} -> 0
      end

    socket = assign(socket, :game_id, game_id)

    # Send current state to joining client
    send(self(), :after_join)

    {:ok, %{value: value}, socket}
  end

  @impl true
  def handle_info(:after_join, socket) do
    # Could add presence tracking here
    {:noreply, socket}
  end

  @impl true
  def handle_info({:game_updated, _game_id, value}, socket) do
    # Forward PubSub updates to the client
    push(socket, "updated", %{value: value})
    {:noreply, socket}
  end

  @impl true
  def handle_in("increment", _params, socket) do
    {:ok, value} = Game.increment(socket.assigns.game_id)
    # Update is broadcast via PubSub, no need to broadcast here
    {:reply, {:ok, %{value: value}}, socket}
  end

  @impl true
  def handle_in("decrement", _params, socket) do
    {:ok, value} = Game.decrement(socket.assigns.game_id)
    {:reply, {:ok, %{value: value}}, socket}
  end

  @impl true
  def handle_in("reset", _params, socket) do
    {:ok, value} = Game.reset(socket.assigns.game_id)
    {:reply, {:ok, %{value: value}}, socket}
  end
end

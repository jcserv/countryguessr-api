defmodule CounterWeb.CounterChannel do
  use Phoenix.Channel

  @moduledoc """
  WebSocket channel for real-time counter updates.

  Demonstrates how WebSocket transport calls the Counter context.
  The same Counter context is also called by HTTP controllers.

  ## Topic

  Join with topic `counter:{id}` where `{id}` is the counter ID.

  ## Events

  ### Client → Server

  - `"increment"` - Increment the counter
  - `"decrement"` - Decrement the counter
  - `"reset"` - Reset the counter to 0

  ### Server → Client

  - `"state"` - Sent on join with current value
  - `"updated"` - Broadcast when counter changes
  """

  require Logger

  @impl true
  def join("counter:" <> counter_id, _params, socket) do
    # Subscribe to counter updates via PubSub
    Counter.subscribe(counter_id)

    # Get current value (or 0 if counter doesn't exist)
    value =
      case Counter.get(counter_id) do
        {:ok, v} -> v
        {:error, :not_found} -> 0
      end

    socket = assign(socket, :counter_id, counter_id)

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
  def handle_info({:counter_updated, _counter_id, value}, socket) do
    # Forward PubSub updates to the client
    push(socket, "updated", %{value: value})
    {:noreply, socket}
  end

  @impl true
  def handle_in("increment", _params, socket) do
    {:ok, value} = Counter.increment(socket.assigns.counter_id)
    # Update is broadcast via PubSub, no need to broadcast here
    {:reply, {:ok, %{value: value}}, socket}
  end

  @impl true
  def handle_in("decrement", _params, socket) do
    {:ok, value} = Counter.decrement(socket.assigns.counter_id)
    {:reply, {:ok, %{value: value}}, socket}
  end

  @impl true
  def handle_in("reset", _params, socket) do
    {:ok, value} = Counter.reset(socket.assigns.counter_id)
    {:reply, {:ok, %{value: value}}, socket}
  end
end

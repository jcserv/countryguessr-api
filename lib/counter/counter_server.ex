defmodule Counter.CounterServer do
  @moduledoc """
  GenServer that holds the state for a single counter.

  Each counter is a separate process, allowing:
  - Concurrent access to different counters
  - Isolation (one counter crashing doesn't affect others)
  - Easy horizontal scaling across nodes

  ## Process Registration

  Counter processes are registered in `Counter.Registry` using their
  counter_id, allowing lookup via `whereis/1`.
  """
  use GenServer

  require Logger

  @idle_timeout :timer.minutes(30)

  # --- Client API ---

  @doc """
  Starts a new counter process.
  """
  def start_link(opts) do
    counter_id = Keyword.fetch!(opts, :counter_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(counter_id))
  end

  @doc """
  Looks up a counter process by ID.
  Returns the pid if found, nil otherwise.
  """
  @spec whereis(String.t()) :: pid() | nil
  def whereis(counter_id) do
    case Registry.lookup(Counter.Registry, counter_id) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  @doc """
  Gets the current counter value.
  """
  @spec get(pid()) :: integer()
  def get(pid) do
    GenServer.call(pid, :get)
  end

  @doc """
  Increments the counter and returns the new value.
  """
  @spec increment(pid()) :: integer()
  def increment(pid) do
    GenServer.call(pid, :increment)
  end

  @doc """
  Decrements the counter and returns the new value.
  """
  @spec decrement(pid()) :: integer()
  def decrement(pid) do
    GenServer.call(pid, :decrement)
  end

  @doc """
  Resets the counter to 0 and returns 0.
  """
  @spec reset(pid()) :: integer()
  def reset(pid) do
    GenServer.call(pid, :reset)
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    counter_id = Keyword.fetch!(opts, :counter_id)
    Logger.info("Starting counter process", counter_id: counter_id)

    state = %{
      counter_id: counter_id,
      value: 0
    }

    {:ok, state, @idle_timeout}
  end

  @impl true
  def handle_call(:get, _from, state) do
    {:reply, state.value, state, @idle_timeout}
  end

  @impl true
  def handle_call(:increment, _from, state) do
    new_value = state.value + 1
    new_state = %{state | value: new_value}
    broadcast_update(state.counter_id, new_value)
    {:reply, new_value, new_state, @idle_timeout}
  end

  @impl true
  def handle_call(:decrement, _from, state) do
    new_value = state.value - 1
    new_state = %{state | value: new_value}
    broadcast_update(state.counter_id, new_value)
    {:reply, new_value, new_state, @idle_timeout}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    new_state = %{state | value: 0}
    broadcast_update(state.counter_id, 0)
    {:reply, 0, new_state, @idle_timeout}
  end

  @impl true
  def handle_info(:timeout, state) do
    Logger.info("Counter idle timeout, shutting down", counter_id: state.counter_id)
    {:stop, :normal, state}
  end

  # --- Private ---

  defp via_tuple(counter_id) do
    {:via, Registry, {Counter.Registry, counter_id}}
  end

  defp broadcast_update(counter_id, value) do
    Phoenix.PubSub.broadcast(
      Counter.PubSub,
      "counter:#{counter_id}",
      {:counter_updated, counter_id, value}
    )
  end
end

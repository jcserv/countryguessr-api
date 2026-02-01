defmodule Counter do
  @moduledoc """
  Counter context - transport-agnostic business logic.

  This module provides the public API for counter operations.
  It can be called from HTTP controllers, WebSocket channels,
  or any future transport layer.

  ## Example

      # Get or create a counter, then increment it
      Counter.increment("my-counter")
      #=> {:ok, 1}

      Counter.get("my-counter")
      #=> {:ok, 1}

      Counter.reset("my-counter")
      #=> {:ok, 0}
  """

  alias Counter.CounterServer

  @doc """
  Gets the current value of a counter.
  Returns `{:ok, value}` or `{:error, :not_found}`.
  """
  @spec get(String.t()) :: {:ok, integer()} | {:error, :not_found}
  def get(counter_id) do
    case CounterServer.whereis(counter_id) do
      nil -> {:error, :not_found}
      pid -> {:ok, CounterServer.get(pid)}
    end
  end

  @doc """
  Increments a counter by 1. Creates the counter if it doesn't exist.
  Returns `{:ok, new_value}`.
  """
  @spec increment(String.t()) :: {:ok, integer()}
  def increment(counter_id) do
    pid = ensure_started(counter_id)
    {:ok, CounterServer.increment(pid)}
  end

  @doc """
  Decrements a counter by 1. Creates the counter if it doesn't exist.
  Returns `{:ok, new_value}`.
  """
  @spec decrement(String.t()) :: {:ok, integer()}
  def decrement(counter_id) do
    pid = ensure_started(counter_id)
    {:ok, CounterServer.decrement(pid)}
  end

  @doc """
  Resets a counter to 0. Creates the counter if it doesn't exist.
  Returns `{:ok, 0}`.
  """
  @spec reset(String.t()) :: {:ok, integer()}
  def reset(counter_id) do
    pid = ensure_started(counter_id)
    {:ok, CounterServer.reset(pid)}
  end

  @doc """
  Subscribes the calling process to counter updates.
  Updates are sent as `{:counter_updated, counter_id, value}`.
  """
  @spec subscribe(String.t()) :: :ok
  def subscribe(counter_id) do
    Phoenix.PubSub.subscribe(Counter.PubSub, "counter:#{counter_id}")
  end

  # Ensures a counter process exists, starting one if needed
  defp ensure_started(counter_id) do
    case CounterServer.whereis(counter_id) do
      nil ->
        case DynamicSupervisor.start_child(
               Counter.DynamicSupervisor,
               {CounterServer, counter_id: counter_id}
             ) do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end

      pid ->
        pid
    end
  end
end

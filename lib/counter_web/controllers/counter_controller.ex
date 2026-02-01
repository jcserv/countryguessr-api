defmodule CounterWeb.CounterController do
  @moduledoc """
  HTTP controller for counter operations.

  Demonstrates how HTTP transport calls the Counter context.
  The same Counter context is also called by WebSocket channels.
  """
  use Phoenix.Controller, formats: [:json]

  @doc """
  GET /api/counters/:id

  Returns the current value of a counter.
  """
  def show(conn, %{"id" => id}) do
    case Counter.get(id) do
      {:ok, value} ->
        json(conn, %{id: id, value: value})

      {:error, :not_found} ->
        # Counter doesn't exist yet, return 0
        json(conn, %{id: id, value: 0})
    end
  end

  @doc """
  POST /api/counters/:id/increment

  Increments the counter and returns the new value.
  """
  def increment(conn, %{"id" => id}) do
    {:ok, value} = Counter.increment(id)
    json(conn, %{id: id, value: value})
  end

  @doc """
  POST /api/counters/:id/decrement

  Decrements the counter and returns the new value.
  """
  def decrement(conn, %{"id" => id}) do
    {:ok, value} = Counter.decrement(id)
    json(conn, %{id: id, value: value})
  end

  @doc """
  POST /api/counters/:id/reset

  Resets the counter to 0.
  """
  def reset(conn, %{"id" => id}) do
    {:ok, value} = Counter.reset(id)
    json(conn, %{id: id, value: value})
  end
end

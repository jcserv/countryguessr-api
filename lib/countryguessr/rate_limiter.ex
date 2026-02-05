defmodule Countryguessr.RateLimiter do
  @moduledoc """
  Simple token bucket rate limiter using ETS.

  Limits requests per player per action within a time window.
  Used to prevent spam on WebSocket events like claim_country.
  """
  use GenServer

  @table_name :rate_limiter
  @default_max_requests 10
  @default_window_ms 1_000

  # --- Client API ---

  @doc """
  Starts the rate limiter GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Checks if a request is allowed for the given player and action.

  Returns `:ok` if allowed, `{:error, :rate_limited}` if rate limit exceeded.

  ## Options
    * `:max_requests` - Maximum requests per window (default: 10)
    * `:window_ms` - Time window in milliseconds (default: 1000)
  """
  @spec check(String.t(), atom(), keyword()) :: :ok | {:error, :rate_limited}
  def check(player_id, action, opts \\ []) do
    max_requests = Keyword.get(opts, :max_requests, @default_max_requests)
    window_ms = Keyword.get(opts, :window_ms, @default_window_ms)

    key = {player_id, action}
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table_name, key) do
      [] ->
        # First request - allow and record
        :ets.insert(@table_name, {key, 1, now})
        :ok

      [{^key, count, window_start}] ->
        check_within_window(key, count, window_start, now, max_requests, window_ms)
    end
  end

  defp check_within_window(key, count, window_start, now, max_requests, window_ms) do
    if now - window_start > window_ms do
      # Window expired - reset
      :ets.insert(@table_name, {key, 1, now})
      :ok
    else
      check_rate_limit(key, count, max_requests)
    end
  end

  defp check_rate_limit(_key, count, max_requests) when count >= max_requests do
    {:error, :rate_limited}
  end

  defp check_rate_limit(key, _count, _max_requests) do
    :ets.update_counter(@table_name, key, {2, 1})
    :ok
  end

  @doc """
  Clears rate limit data for a specific player.
  Useful when a player disconnects.
  """
  @spec clear(String.t()) :: :ok
  def clear(player_id) do
    # Match all keys starting with this player_id
    :ets.match_delete(@table_name, {{player_id, :_}, :_, :_})
    :ok
  end

  @doc """
  Clears all rate limit data.
  """
  @spec clear_all() :: :ok
  def clear_all do
    :ets.delete_all_objects(@table_name)
    :ok
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    # Create ETS table for rate limiting data
    # Using :public so channel processes can access it directly
    :ets.new(@table_name, [:named_table, :public, :set])
    {:ok, %{}}
  end
end

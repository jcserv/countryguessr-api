defmodule Countryguessr.GameServer do
  @moduledoc """
  GenServer that holds the state for a competitive multiplayer game.

  Each game is a separate process, allowing:
  - Concurrent access to different games
  - Isolation (one game crashing doesn't affect others)
  - Easy horizontal scaling across nodes

  ## Game States
  - :lobby - Waiting for players, host can start
  - :playing - Game in progress, players claim countries
  - :finished - Game over, showing results

  ## Process Registration

  Game processes are registered in `Countryguessr.Registry` using their
  game_id, allowing lookup via `whereis/1`.
  """
  use GenServer

  require Logger

  @idle_timeout :timer.minutes(30)
  @game_duration :timer.minutes(30)
  @timer_interval :timer.seconds(1)
  @total_countries 178

  # --- Client API ---

  @doc """
  Starts a new game process.
  """
  def start_link(opts) do
    game_id = Keyword.fetch!(opts, :game_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(game_id))
  end

  @doc """
  Looks up a game process by ID.
  Returns the pid if found, nil otherwise.
  """
  @spec whereis(String.t()) :: pid() | nil
  def whereis(game_id) do
    case Registry.lookup(Countryguessr.Registry, game_id) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  @doc """
  Gets the full game state.
  """
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  @doc """
  Adds a player to the game.
  """
  def join(pid, player_id, nickname) do
    GenServer.call(pid, {:join, player_id, nickname})
  end

  @doc """
  Removes a player from the game (marks as disconnected).
  """
  def leave(pid, player_id) do
    GenServer.call(pid, {:leave, player_id})
  end

  @doc """
  Starts the game (host only).
  """
  def start_game(pid, player_id) do
    GenServer.call(pid, {:start_game, player_id})
  end

  @doc """
  Claims a country for a player.
  """
  def claim_country(pid, player_id, country_code) do
    GenServer.call(pid, {:claim_country, player_id, country_code})
  end

  # --- Legacy API for backwards compatibility ---

  @doc """
  Gets the current game value (legacy counter API).
  """
  @spec get(pid()) :: integer()
  def get(pid) do
    GenServer.call(pid, :get)
  end

  @doc """
  Increments the game and returns the new value (legacy).
  """
  @spec increment(pid()) :: integer()
  def increment(pid) do
    GenServer.call(pid, :increment)
  end

  @doc """
  Decrements the game and returns the new value (legacy).
  """
  @spec decrement(pid()) :: integer()
  def decrement(pid) do
    GenServer.call(pid, :decrement)
  end

  @doc """
  Resets the game to 0 and returns 0 (legacy).
  """
  @spec reset(pid()) :: integer()
  def reset(pid) do
    GenServer.call(pid, :reset)
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    game_id = Keyword.fetch!(opts, :game_id)
    Logger.info("Starting game process", game_id: game_id)

    state = %{
      game_id: game_id,
      status: :lobby,
      host_id: nil,
      players: %{},
      claimed_countries: %{},
      started_at: nil,
      ended_at: nil,
      time_remaining: div(@game_duration, 1000),
      timer_ref: nil,
      # Legacy counter value for backwards compatibility
      value: 0
    }

    {:ok, state, @idle_timeout}
  end

  # --- Competitive Game Handlers ---

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, format_state(state), state, @idle_timeout}
  end

  @impl true
  def handle_call({:join, player_id, nickname}, _from, state) do
    cond do
      # Already in game
      Map.has_key?(state.players, player_id) ->
        # Reconnecting - mark as connected
        player = state.players[player_id]
        updated_player = %{player | is_connected: true}
        new_players = Map.put(state.players, player_id, updated_player)
        new_state = %{state | players: new_players}

        broadcast_player_joined(state.game_id, player_id, nickname, player.is_host)
        {:reply, {:ok, format_state(new_state)}, new_state, @idle_timeout}

      # Game already started - can't join
      state.status != :lobby ->
        {:reply, {:error, :game_already_started}, state, @idle_timeout}

      true ->
        # First player becomes host
        is_host = map_size(state.players) == 0
        host_id = if is_host, do: player_id, else: state.host_id

        player = %{
          id: player_id,
          nickname: nickname,
          claimed_countries: [],
          is_host: is_host,
          is_connected: true
        }

        new_players = Map.put(state.players, player_id, player)
        new_state = %{state | players: new_players, host_id: host_id}

        broadcast_player_joined(state.game_id, player_id, nickname, is_host)
        {:reply, {:ok, format_state(new_state)}, new_state, @idle_timeout}
    end
  end

  @impl true
  def handle_call({:leave, player_id}, _from, state) do
    case Map.get(state.players, player_id) do
      nil ->
        {:reply, {:error, :not_in_game}, state, @idle_timeout}

      player ->
        updated_player = %{player | is_connected: false}
        new_players = Map.put(state.players, player_id, updated_player)
        new_state = %{state | players: new_players}

        broadcast_player_left(state.game_id, player_id)
        {:reply, :ok, new_state, @idle_timeout}
    end
  end

  @impl true
  def handle_call({:start_game, player_id}, _from, state) do
    cond do
      state.status != :lobby ->
        {:reply, {:error, :game_not_in_lobby}, state, @idle_timeout}

      state.host_id != player_id ->
        {:reply, {:error, :not_host}, state, @idle_timeout}

      map_size(state.players) < 1 ->
        {:reply, {:error, :not_enough_players}, state, @idle_timeout}

      true ->
        started_at = System.system_time(:millisecond)
        timer_ref = Process.send_after(self(), :timer_tick, @timer_interval)

        new_state = %{
          state
          | status: :playing,
            started_at: started_at,
            time_remaining: div(@game_duration, 1000),
            timer_ref: timer_ref
        }

        broadcast_game_started(state.game_id, started_at)
        {:reply, {:ok, format_state(new_state)}, new_state, @idle_timeout}
    end
  end

  @impl true
  def handle_call({:claim_country, player_id, country_code}, _from, state) do
    cond do
      state.status != :playing ->
        {:reply, {:error, :game_not_playing}, state, @idle_timeout}

      not Map.has_key?(state.players, player_id) ->
        {:reply, {:error, :not_in_game}, state, @idle_timeout}

      Map.has_key?(state.claimed_countries, country_code) ->
        {:reply, {:error, :already_claimed}, state, @idle_timeout}

      true ->
        # Claim the country
        new_claimed = Map.put(state.claimed_countries, country_code, player_id)

        # Update player's claimed countries list
        player = state.players[player_id]
        updated_player = %{player | claimed_countries: [country_code | player.claimed_countries]}
        new_players = Map.put(state.players, player_id, updated_player)

        new_state = %{state | claimed_countries: new_claimed, players: new_players}

        broadcast_country_claimed(state.game_id, player_id, country_code)

        # Check if all countries are claimed
        new_state =
          if map_size(new_claimed) >= @total_countries do
            end_game(new_state)
          else
            new_state
          end

        {:reply, {:ok, %{success: true}}, new_state, @idle_timeout}
    end
  end

  # --- Legacy Counter Handlers (for backwards compatibility) ---

  @impl true
  def handle_call(:get, _from, state) do
    {:reply, state.value, state, @idle_timeout}
  end

  @impl true
  def handle_call(:increment, _from, state) do
    new_value = state.value + 1
    new_state = %{state | value: new_value}
    broadcast_update(state.game_id, new_value)
    {:reply, new_value, new_state, @idle_timeout}
  end

  @impl true
  def handle_call(:decrement, _from, state) do
    new_value = state.value - 1
    new_state = %{state | value: new_value}
    broadcast_update(state.game_id, new_value)
    {:reply, new_value, new_state, @idle_timeout}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    new_state = %{state | value: 0}
    broadcast_update(state.game_id, 0)
    {:reply, 0, new_state, @idle_timeout}
  end

  # --- Timer and Timeout Handlers ---

  @impl true
  def handle_info(:timer_tick, state) do
    if state.status == :playing do
      new_time = state.time_remaining - 1

      if new_time <= 0 do
        new_state = end_game(%{state | time_remaining: 0, timer_ref: nil})
        {:noreply, new_state, @idle_timeout}
      else
        broadcast_timer_tick(state.game_id, new_time)
        timer_ref = Process.send_after(self(), :timer_tick, @timer_interval)
        new_state = %{state | time_remaining: new_time, timer_ref: timer_ref}
        {:noreply, new_state, @idle_timeout}
      end
    else
      {:noreply, state, @idle_timeout}
    end
  end

  @impl true
  def handle_info(:timeout, state) do
    Logger.info("Game idle timeout, shutting down", game_id: state.game_id)
    # Notify connected clients before shutdown
    broadcast_game_shutdown(state.game_id, :idle_timeout)
    {:stop, :normal, state}
  end

  # --- Private ---

  defp via_tuple(game_id) do
    {:via, Registry, {Countryguessr.Registry, game_id}}
  end

  defp format_state(state) do
    %{
      game_id: state.game_id,
      status: state.status,
      host_id: state.host_id,
      players: format_players(state.players),
      claimed_countries: state.claimed_countries,
      started_at: state.started_at,
      ended_at: state.ended_at,
      time_remaining: state.time_remaining
    }
  end

  defp format_players(players) do
    Map.new(players, fn {id, player} ->
      {id,
       %{
         id: player.id,
         nickname: player.nickname,
         claimed_countries: player.claimed_countries,
         is_host: player.is_host,
         is_connected: player.is_connected
       }}
    end)
  end

  defp end_game(state) do
    # Cancel timer if running
    if state.timer_ref, do: Process.cancel_timer(state.timer_ref)

    ended_at = System.system_time(:millisecond)
    new_state = %{state | status: :finished, ended_at: ended_at, timer_ref: nil}

    # Calculate rankings
    rankings = calculate_rankings(state.players)
    winner_id = if Enum.any?(rankings), do: hd(rankings).player_id, else: nil

    broadcast_game_ended(state.game_id, ended_at, winner_id, rankings)
    new_state
  end

  defp calculate_rankings(players) do
    players
    |> Enum.map(fn {id, player} ->
      %{
        player_id: id,
        nickname: player.nickname,
        claimed_count: length(player.claimed_countries)
      }
    end)
    |> Enum.sort_by(& &1.claimed_count, :desc)
  end

  # --- Broadcasts ---

  defp broadcast_update(game_id, value) do
    Phoenix.PubSub.broadcast(
      Countryguessr.PubSub,
      "game:#{game_id}",
      {:game_updated, game_id, value}
    )
  end

  defp broadcast_player_joined(game_id, player_id, nickname, is_host) do
    Phoenix.PubSub.broadcast(
      Countryguessr.PubSub,
      "game:#{game_id}",
      {:player_joined, player_id, nickname, is_host}
    )
  end

  defp broadcast_player_left(game_id, player_id) do
    Phoenix.PubSub.broadcast(
      Countryguessr.PubSub,
      "game:#{game_id}",
      {:player_left, player_id}
    )
  end

  defp broadcast_game_started(game_id, started_at) do
    Phoenix.PubSub.broadcast(
      Countryguessr.PubSub,
      "game:#{game_id}",
      {:game_started, started_at}
    )
  end

  defp broadcast_country_claimed(game_id, player_id, country_code) do
    Phoenix.PubSub.broadcast(
      Countryguessr.PubSub,
      "game:#{game_id}",
      {:country_claimed, player_id, country_code}
    )
  end

  defp broadcast_timer_tick(game_id, time_remaining) do
    Phoenix.PubSub.broadcast(
      Countryguessr.PubSub,
      "game:#{game_id}",
      {:timer_tick, time_remaining}
    )
  end

  defp broadcast_game_ended(game_id, ended_at, winner_id, rankings) do
    Phoenix.PubSub.broadcast(
      Countryguessr.PubSub,
      "game:#{game_id}",
      {:game_ended, ended_at, winner_id, rankings}
    )
  end

  defp broadcast_game_shutdown(game_id, reason) do
    Phoenix.PubSub.broadcast(
      Countryguessr.PubSub,
      "game:#{game_id}",
      {:game_shutdown, reason}
    )
  end
end

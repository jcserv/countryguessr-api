defmodule CountryguessrWeb.GameChannel do
  use Phoenix.Channel

  @moduledoc """
  WebSocket channel for real-time competitive multiplayer games.

  ## Topic

  Join with topic `game:{id}` where `{id}` is the game/room ID.

  ## Events

  ### Client → Server

  - `"start_game"` - Start the game (host only)
  - `"claim_country"` - Claim a country `%{"country_code" => "US"}`
  - `"increment"` / `"decrement"` / `"reset"` - Legacy counter API

  ### Server → Client

  - `"game_state"` - Full state sync (sent on join)
  - `"player_joined"` - A player joined the game
  - `"player_left"` - A player disconnected
  - `"game_started"` - Game has started
  - `"country_claimed"` - A country was claimed
  - `"timer_tick"` - Timer update (every second during game)
  - `"game_ended"` - Game has ended with rankings
  - `"updated"` - Legacy counter update
  """

  alias Countryguessr.Countries
  alias Countryguessr.Game
  alias Countryguessr.RateLimiter

  require Logger

  @impl true
  def join("game:" <> game_id, params, socket) do
    # Subscribe to game updates via PubSub
    Game.subscribe(game_id)

    # Get player info from params or socket assigns
    player_id = socket.assigns[:player_id] || Map.get(params, "player_id", generate_id())
    nickname = Map.get(params, "nickname", "Player")

    # Join the game
    case Game.join(game_id, player_id, nickname) do
      {:ok, state} ->
        socket =
          socket
          |> assign(:game_id, game_id)
          |> assign(:player_id, player_id)

        # Send full state to joining client
        {:ok, format_state_for_client(state), socket}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  # =============================================================================
  # Client → Server Event Handlers
  # =============================================================================

  @impl true
  def handle_in("start_game", _params, socket) do
    game_id = socket.assigns.game_id
    player_id = socket.assigns.player_id

    case Game.start_game(game_id, player_id) do
      {:ok, _state} ->
        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  @impl true
  def handle_in("claim_country", %{"country_code" => country_code}, socket) do
    game_id = socket.assigns.game_id
    player_id = socket.assigns.player_id

    with :ok <- validate_country_code(country_code),
         :ok <- RateLimiter.check(player_id, :claim_country) do
      case Game.claim_country(game_id, player_id, country_code) do
        {:ok, result} ->
          {:reply, {:ok, result}, socket}

        {:error, reason} ->
          {:reply, {:error, %{reason: reason}}, socket}
      end
    else
      {:error, :invalid_country_code} ->
        {:reply, {:error, %{reason: :invalid_country_code}}, socket}

      {:error, :rate_limited} ->
        {:reply, {:error, %{reason: :rate_limited}}, socket}
    end
  end

  # Legacy counter API
  @impl true
  def handle_in("increment", _params, socket) do
    {:ok, value} = Game.increment(socket.assigns.game_id)
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

  @impl true
  def handle_in("end_game", _params, socket) do
    game_id = socket.assigns.game_id
    player_id = socket.assigns.player_id

    case Game.end_game(game_id, player_id) do
      :ok -> {:reply, :ok, socket}
      {:error, reason} -> {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  # Catch-all for unknown events
  @impl true
  def handle_in(event, _params, socket) do
    Logger.warning("Unknown event received: #{event}")
    {:reply, {:error, %{reason: :unknown_event}}, socket}
  end

  # =============================================================================
  # PubSub Message Handlers (Server → Client broadcasts)
  # =============================================================================

  @impl true
  def handle_info({:player_joined, player_id, nickname, is_host}, socket) do
    push(socket, "player_joined", %{
      player_id: player_id,
      nickname: nickname,
      is_host: is_host
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:player_left, player_id}, socket) do
    push(socket, "player_left", %{player_id: player_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:game_started, started_at}, socket) do
    push(socket, "game_started", %{started_at: started_at})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:country_claimed, player_id, country_code}, socket) do
    push(socket, "country_claimed", %{
      player_id: player_id,
      country_code: country_code
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:timer_tick, time_remaining}, socket) do
    push(socket, "timer_tick", %{time_remaining: time_remaining})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:game_ended, ended_at, winner_id, rankings}, socket) do
    push(socket, "game_ended", %{
      ended_at: ended_at,
      winner_id: winner_id,
      rankings: rankings
    })

    {:noreply, socket}
  end

  # Legacy counter update
  @impl true
  def handle_info({:game_updated, _game_id, value}, socket) do
    push(socket, "updated", %{value: value})
    {:noreply, socket}
  end

  # Game shutdown notification
  @impl true
  def handle_info({:game_shutdown, reason}, socket) do
    push(socket, "game_shutdown", %{reason: reason})
    {:noreply, socket}
  end

  # =============================================================================
  # Termination
  # =============================================================================

  @impl true
  def terminate(_reason, socket) do
    # Mark player as disconnected when they leave
    if Map.has_key?(socket.assigns, :game_id) and Map.has_key?(socket.assigns, :player_id) do
      Game.leave(socket.assigns.game_id, socket.assigns.player_id)
      RateLimiter.clear(socket.assigns.player_id)
    end

    :ok
  end

  # =============================================================================
  # Private
  # =============================================================================

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp validate_country_code(code) when is_binary(code) do
    if Countries.valid?(code) do
      :ok
    else
      {:error, :invalid_country_code}
    end
  end

  defp validate_country_code(_), do: {:error, :invalid_country_code}

  defp format_state_for_client(state) do
    %{
      game_id: state.game_id,
      status: state.status,
      host_id: state.host_id,
      players: state.players,
      claimed_countries: state.claimed_countries,
      started_at: state.started_at,
      ended_at: state.ended_at,
      time_remaining: state.time_remaining
    }
  end
end

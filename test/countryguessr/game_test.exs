defmodule Countryguessr.GameTest do
  use ExUnit.Case, async: true

  alias Countryguessr.Game

  describe "competitive game: join/3" do
    test "creates game and adds first player as host" do
      game_id = "game-#{System.unique_integer()}"
      player_id = "player-1"

      assert {:ok, state} = Game.join(game_id, player_id, "Alice")

      assert state.game_id == game_id
      assert state.status == :lobby
      assert state.host_id == player_id
      assert Map.has_key?(state.players, player_id)
      assert state.players[player_id].is_host == true
      assert state.players[player_id].nickname == "Alice"
    end

    test "adds subsequent players as non-hosts" do
      game_id = "game-#{System.unique_integer()}"

      {:ok, _} = Game.join(game_id, "player-1", "Alice")
      {:ok, state} = Game.join(game_id, "player-2", "Bob")

      assert Map.has_key?(state.players, "player-2")
      assert state.players["player-2"].is_host == false
      assert state.host_id == "player-1"
    end

    test "allows reconnection for existing player" do
      game_id = "game-#{System.unique_integer()}"
      player_id = "player-1"

      {:ok, _} = Game.join(game_id, player_id, "Alice")
      Game.leave(game_id, player_id)
      {:ok, state} = Game.join(game_id, player_id, "Alice")

      assert state.players[player_id].is_connected == true
    end

    test "rejects join after game started" do
      game_id = "game-#{System.unique_integer()}"
      host_id = "player-1"

      {:ok, _} = Game.join(game_id, host_id, "Alice")
      {:ok, _} = Game.start_game(game_id, host_id)

      assert {:error, :game_already_started} = Game.join(game_id, "player-2", "Bob")
    end
  end

  describe "competitive game: leave/2" do
    test "marks player as disconnected" do
      game_id = "game-#{System.unique_integer()}"
      player_id = "player-1"

      {:ok, _} = Game.join(game_id, player_id, "Alice")
      assert :ok = Game.leave(game_id, player_id)
      {:ok, state} = Game.get_state(game_id)

      assert state.players[player_id].is_connected == false
    end

    test "returns error for non-existent game" do
      assert {:error, :not_found} = Game.leave("nonexistent", "player-1")
    end

    test "returns error for player not in game" do
      game_id = "game-#{System.unique_integer()}"
      {:ok, _} = Game.join(game_id, "player-1", "Alice")

      assert {:error, :not_in_game} = Game.leave(game_id, "player-2")
    end
  end

  describe "competitive game: start_game/2" do
    test "starts game when called by host" do
      game_id = "game-#{System.unique_integer()}"
      host_id = "player-1"

      {:ok, _} = Game.join(game_id, host_id, "Alice")
      {:ok, state} = Game.start_game(game_id, host_id)

      assert state.status == :playing
      assert state.started_at != nil
      assert state.time_remaining > 0
    end

    test "rejects start from non-host" do
      game_id = "game-#{System.unique_integer()}"

      {:ok, _} = Game.join(game_id, "player-1", "Alice")
      {:ok, _} = Game.join(game_id, "player-2", "Bob")

      assert {:error, :not_host} = Game.start_game(game_id, "player-2")
    end

    test "rejects start when game already started" do
      game_id = "game-#{System.unique_integer()}"
      host_id = "player-1"

      {:ok, _} = Game.join(game_id, host_id, "Alice")
      {:ok, _} = Game.start_game(game_id, host_id)

      assert {:error, :game_not_in_lobby} = Game.start_game(game_id, host_id)
    end

    test "returns error for non-existent game" do
      assert {:error, :not_found} = Game.start_game("nonexistent", "player-1")
    end
  end

  describe "competitive game: claim_country/3" do
    setup do
      game_id = "game-#{System.unique_integer()}"
      host_id = "player-1"

      {:ok, _} = Game.join(game_id, host_id, "Alice")
      {:ok, _} = Game.join(game_id, "player-2", "Bob")
      {:ok, _} = Game.start_game(game_id, host_id)

      %{game_id: game_id, host_id: host_id}
    end

    test "awards country to first claimer", %{game_id: game_id, host_id: host_id} do
      {:ok, result} = Game.claim_country(game_id, host_id, "US")
      assert result.success == true

      {:ok, state} = Game.get_state(game_id)
      assert state.claimed_countries["US"] == host_id
      assert "US" in state.players[host_id].claimed_countries
    end

    test "rejects already claimed country", %{game_id: game_id, host_id: host_id} do
      {:ok, _} = Game.claim_country(game_id, host_id, "US")

      assert {:error, :already_claimed} = Game.claim_country(game_id, "player-2", "US")
    end

    test "allows different players to claim different countries", %{
      game_id: game_id,
      host_id: host_id
    } do
      {:ok, _} = Game.claim_country(game_id, host_id, "US")
      {:ok, result} = Game.claim_country(game_id, "player-2", "FR")

      assert result.success == true

      {:ok, state} = Game.get_state(game_id)
      assert state.claimed_countries["US"] == host_id
      assert state.claimed_countries["FR"] == "player-2"
    end

    test "rejects claim when game not playing" do
      game_id = "game-#{System.unique_integer()}"
      {:ok, _} = Game.join(game_id, "player-1", "Alice")

      # Game in lobby - not started
      assert {:error, :game_not_playing} = Game.claim_country(game_id, "player-1", "US")
    end

    test "rejects claim from player not in game", %{game_id: game_id} do
      assert {:error, :not_in_game} = Game.claim_country(game_id, "unknown-player", "US")
    end

    test "returns error for non-existent game" do
      assert {:error, :not_found} = Game.claim_country("nonexistent", "player-1", "US")
    end
  end

  describe "competitive game: submit_guess/4" do
    setup do
      game_id = "game-#{System.unique_integer()}"
      host_id = "player-1"

      {:ok, _} = Game.join(game_id, host_id, "Alice")
      {:ok, _} = Game.join(game_id, "player-2", "Bob")
      {:ok, _} = Game.start_game(game_id, host_id)

      %{game_id: game_id, host_id: host_id}
    end

    test "correct guess claims the country", %{game_id: game_id, host_id: host_id} do
      {:ok, result} = Game.submit_guess(game_id, host_id, "US", "US")
      assert result.correct == true
      assert result.success == true

      {:ok, state} = Game.get_state(game_id)
      assert state.claimed_countries["US"] == host_id
      assert "US" in state.players[host_id].claimed_countries
    end

    test "incorrect guess loses a life", %{game_id: game_id, host_id: host_id} do
      {:ok, result} = Game.submit_guess(game_id, host_id, "US", "FR")
      assert result.correct == false
      assert result.lives == 2
      assert result.is_eliminated == false

      {:ok, state} = Game.get_state(game_id)
      assert state.players[host_id].lives == 2
      assert state.players[host_id].is_eliminated == false
      # Country should NOT be claimed
      refute Map.has_key?(state.claimed_countries, "US")
    end

    test "three wrong guesses eliminates player", %{game_id: game_id, host_id: host_id} do
      {:ok, _} = Game.submit_guess(game_id, host_id, "US", "FR")
      {:ok, _} = Game.submit_guess(game_id, host_id, "US", "FR")
      {:ok, result} = Game.submit_guess(game_id, host_id, "US", "FR")

      assert result.correct == false
      assert result.lives == 0
      assert result.is_eliminated == true

      {:ok, state} = Game.get_state(game_id)
      assert state.players[host_id].lives == 0
      assert state.players[host_id].is_eliminated == true
    end

    test "eliminated player cannot submit guesses" do
      # Need 3 players so eliminating one doesn't end the game
      game_id = "game-#{System.unique_integer()}"
      host_id = "player-1"

      {:ok, _} = Game.join(game_id, host_id, "Alice")
      {:ok, _} = Game.join(game_id, "player-2", "Bob")
      {:ok, _} = Game.join(game_id, "player-3", "Charlie")
      {:ok, _} = Game.start_game(game_id, host_id)

      # Eliminate player-2
      {:ok, _} = Game.submit_guess(game_id, "player-2", "US", "FR")
      {:ok, _} = Game.submit_guess(game_id, "player-2", "US", "FR")
      {:ok, _} = Game.submit_guess(game_id, "player-2", "US", "FR")

      assert {:error, :player_eliminated} = Game.submit_guess(game_id, "player-2", "US", "US")
    end

    test "rejects guess for already claimed country", %{game_id: game_id, host_id: host_id} do
      {:ok, _} = Game.submit_guess(game_id, host_id, "US", "US")
      assert {:error, :already_claimed} = Game.submit_guess(game_id, "player-2", "US", "US")
    end

    test "game ends when only 1 player remains", %{game_id: game_id} do
      # Eliminate player-2 (3 wrong guesses)
      {:ok, _} = Game.submit_guess(game_id, "player-2", "US", "FR")
      {:ok, _} = Game.submit_guess(game_id, "player-2", "US", "FR")
      {:ok, _} = Game.submit_guess(game_id, "player-2", "US", "FR")

      {:ok, state} = Game.get_state(game_id)
      assert state.status == :finished
    end

    test "players start with 3 lives", %{game_id: game_id, host_id: host_id} do
      {:ok, state} = Game.get_state(game_id)
      assert state.players[host_id].lives == 3
      assert state.players[host_id].is_eliminated == false
    end

    test "rejects guess when game not playing" do
      game_id = "game-#{System.unique_integer()}"
      {:ok, _} = Game.join(game_id, "player-1", "Alice")

      assert {:error, :game_not_playing} = Game.submit_guess(game_id, "player-1", "US", "US")
    end

    test "returns error for non-existent game" do
      assert {:error, :not_found} = Game.submit_guess("nonexistent", "player-1", "US", "US")
    end
  end

  describe "competitive game: get_state/1" do
    test "returns game state" do
      game_id = "game-#{System.unique_integer()}"
      {:ok, _} = Game.join(game_id, "player-1", "Alice")

      {:ok, state} = Game.get_state(game_id)

      assert state.game_id == game_id
      assert state.status == :lobby
    end

    test "returns error for non-existent game" do
      assert {:error, :not_found} = Game.get_state("nonexistent")
    end
  end
end

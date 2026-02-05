defmodule CountryguessrWeb.GameChannelTest do
  use CountryguessrWeb.ChannelCase

  alias Countryguessr.RateLimiter

  # Use unique game ID per test to avoid state pollution
  setup do
    game_id = "test-#{System.unique_integer([:positive])}"
    player_id = "test-player-#{System.unique_integer([:positive])}"

    {:ok, reply, socket} =
      CountryguessrWeb.UserSocket
      |> socket("user_id", %{player_id: player_id})
      |> subscribe_and_join(
        CountryguessrWeb.GameChannel,
        "game:#{game_id}",
        %{"nickname" => "TestPlayer", "player_id" => player_id}
      )

    # Clear rate limiter for clean tests
    RateLimiter.clear(player_id)

    %{socket: socket, game_id: game_id, player_id: player_id, join_reply: reply}
  end

  describe "join" do
    test "returns game state on join", %{join_reply: reply} do
      assert Map.has_key?(reply, :game_id)
      assert Map.has_key?(reply, :status)
      assert Map.has_key?(reply, :players)
    end

    test "first player becomes host", %{join_reply: reply, player_id: player_id} do
      assert reply.host_id == player_id
      assert reply.players[player_id].is_host == true
    end
  end

  describe "start_game" do
    test "host can start game", %{socket: socket} do
      ref = push(socket, "start_game", %{})
      assert_reply ref, :ok

      assert_push "game_started", %{started_at: started_at}
      assert is_integer(started_at)
    end

    test "non-host cannot start game", %{game_id: game_id} do
      # Join as a second player
      player2_id = "player-2-#{System.unique_integer([:positive])}"

      {:ok, _, socket2} =
        CountryguessrWeb.UserSocket
        |> socket("user_id", %{player_id: player2_id})
        |> subscribe_and_join(
          CountryguessrWeb.GameChannel,
          "game:#{game_id}",
          %{"nickname" => "Player2", "player_id" => player2_id}
        )

      ref = push(socket2, "start_game", %{})
      assert_reply ref, :error, %{reason: :not_host}
    end
  end

  describe "claim_country" do
    setup %{socket: socket} do
      # Start the game first
      ref = push(socket, "start_game", %{})
      assert_reply ref, :ok
      assert_push "game_started", _

      :ok
    end

    test "successfully claims valid country", %{socket: socket, player_id: player_id} do
      ref = push(socket, "claim_country", %{"country_code" => "US"})
      assert_reply ref, :ok, %{success: true}

      assert_push "country_claimed", %{
        player_id: ^player_id,
        country_code: "US"
      }
    end

    test "rejects already claimed country", %{socket: _socket, game_id: _game_id} do
      # Need to set up a fresh game with 2 players before starting
      new_game_id = "test-#{System.unique_integer([:positive])}"
      player1_id = "player-1-#{System.unique_integer([:positive])}"
      player2_id = "player-2-#{System.unique_integer([:positive])}"

      # Player 1 joins
      {:ok, _, socket1} =
        CountryguessrWeb.UserSocket
        |> socket("user_id", %{player_id: player1_id})
        |> subscribe_and_join(
          CountryguessrWeb.GameChannel,
          "game:#{new_game_id}",
          %{"nickname" => "Player1", "player_id" => player1_id}
        )

      # Player 2 joins BEFORE game starts
      {:ok, _, socket2} =
        CountryguessrWeb.UserSocket
        |> socket("user_id", %{player_id: player2_id})
        |> subscribe_and_join(
          CountryguessrWeb.GameChannel,
          "game:#{new_game_id}",
          %{"nickname" => "Player2", "player_id" => player2_id}
        )

      # Start the game
      ref = push(socket1, "start_game", %{})
      assert_reply ref, :ok
      assert_push "game_started", _

      # Player 1 claims country
      ref = push(socket1, "claim_country", %{"country_code" => "US"})
      assert_reply ref, :ok, %{success: true}
      assert_push "country_claimed", _

      # Player 2 tries to claim same country
      ref2 = push(socket2, "claim_country", %{"country_code" => "US"})
      assert_reply ref2, :error, %{reason: :already_claimed}
    end

    test "rejects invalid country code format", %{socket: socket} do
      # Invalid code not in list
      ref = push(socket, "claim_country", %{"country_code" => "USA"})
      assert_reply ref, :error, %{reason: :invalid_country_code}

      # Lowercase
      ref = push(socket, "claim_country", %{"country_code" => "us"})
      assert_reply ref, :error, %{reason: :invalid_country_code}

      # Numbers
      ref = push(socket, "claim_country", %{"country_code" => "12"})
      assert_reply ref, :error, %{reason: :invalid_country_code}

      # Empty
      ref = push(socket, "claim_country", %{"country_code" => ""})
      assert_reply ref, :error, %{reason: :invalid_country_code}
    end

    test "accepts special country codes for disputed territories", %{
      socket: socket,
      player_id: player_id
    } do
      # Northern Cyprus
      ref = push(socket, "claim_country", %{"country_code" => "SYN_NORTHERN_CYPRUS"})
      assert_reply ref, :ok, %{success: true}

      assert_push "country_claimed", %{
        player_id: ^player_id,
        country_code: "SYN_NORTHERN_CYPRUS"
      }

      # Somaliland
      ref = push(socket, "claim_country", %{"country_code" => "SYN_SOMALILAND"})
      assert_reply ref, :ok, %{success: true}

      assert_push "country_claimed", %{
        player_id: ^player_id,
        country_code: "SYN_SOMALILAND"
      }
    end

    test "rate limits excessive claims", %{socket: socket, player_id: _player_id} do
      # Make many rapid claims (different countries to avoid already_claimed)
      countries = ["US", "FR", "GB", "DE", "IT", "ES", "JP", "CN", "AU", "BR"]

      for country <- countries do
        ref = push(socket, "claim_country", %{"country_code" => country})
        assert_reply ref, :ok, %{success: true}
      end

      # 11th request should be rate limited
      ref = push(socket, "claim_country", %{"country_code" => "CA"})
      assert_reply ref, :error, %{reason: :rate_limited}
    end
  end

  describe "player_joined broadcast" do
    test "broadcasts when new player joins", %{game_id: game_id} do
      player2_id = "player-2-#{System.unique_integer([:positive])}"

      {:ok, _, _socket2} =
        CountryguessrWeb.UserSocket
        |> socket("user_id", %{player_id: player2_id})
        |> subscribe_and_join(
          CountryguessrWeb.GameChannel,
          "game:#{game_id}",
          %{"nickname" => "Player2", "player_id" => player2_id}
        )

      assert_push "player_joined", %{
        player_id: ^player2_id,
        nickname: "Player2",
        is_host: false
      }
    end
  end

  describe "unknown events" do
    test "returns error for unknown event", %{socket: socket} do
      ref = push(socket, "unknown_event", %{})
      assert_reply ref, :error, %{reason: :unknown_event}
    end
  end

  describe "legacy counter API" do
    test "increments game and broadcasts update", %{socket: socket} do
      ref = push(socket, "increment", %{})
      assert_reply ref, :ok, %{value: 1}
      assert_push "updated", %{value: 1}
    end

    test "decrements game", %{socket: socket} do
      ref = push(socket, "increment", %{})
      assert_reply ref, :ok, %{value: 1}

      ref = push(socket, "decrement", %{})
      assert_reply ref, :ok, %{value: 0}
    end

    test "resets game and broadcasts update", %{socket: socket} do
      ref = push(socket, "increment", %{})
      assert_reply ref, :ok, %{value: 1}

      ref = push(socket, "increment", %{})
      assert_reply ref, :ok, %{value: 2}

      ref = push(socket, "reset", %{})
      assert_reply ref, :ok, %{value: 0}
      assert_push "updated", %{value: 0}
    end
  end
end

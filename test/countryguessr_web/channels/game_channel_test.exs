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

  describe "submit_guess" do
    setup %{socket: socket} do
      # Start the game first
      ref = push(socket, "start_game", %{})
      assert_reply ref, :ok
      assert_push "game_started", _

      :ok
    end

    test "correct guess claims country", %{socket: socket, player_id: player_id} do
      ref = push(socket, "submit_guess", %{"clicked_country" => "US", "guessed_country" => "US"})
      assert_reply ref, :ok, %{correct: true, success: true}

      assert_push "country_claimed", %{
        player_id: ^player_id,
        country_code: "US"
      }
    end

    test "incorrect guess loses a life and broadcasts", %{socket: socket, player_id: player_id} do
      ref = push(socket, "submit_guess", %{"clicked_country" => "US", "guessed_country" => "FR"})
      assert_reply ref, :ok, %{correct: false, lives: 2, is_eliminated: false}

      assert_push "life_lost", %{
        player_id: ^player_id,
        lives_remaining: 2
      }
    end

    test "three wrong guesses eliminates player", %{socket: socket, player_id: player_id} do
      ref = push(socket, "submit_guess", %{"clicked_country" => "US", "guessed_country" => "FR"})
      assert_reply ref, :ok, %{correct: false, lives: 2}
      assert_push "life_lost", _

      ref = push(socket, "submit_guess", %{"clicked_country" => "US", "guessed_country" => "FR"})
      assert_reply ref, :ok, %{correct: false, lives: 1}
      assert_push "life_lost", _

      ref = push(socket, "submit_guess", %{"clicked_country" => "US", "guessed_country" => "FR"})
      assert_reply ref, :ok, %{correct: false, lives: 0, is_eliminated: true}

      assert_push "life_lost", %{
        player_id: ^player_id,
        lives_remaining: 0
      }

      assert_push "player_eliminated", %{
        player_id: ^player_id
      }
    end

    test "eliminated player cannot guess" do
      # Need 3 players so eliminating one doesn't end the game
      new_game_id = "test-#{System.unique_integer([:positive])}"
      player1_id = "player-1-#{System.unique_integer([:positive])}"
      player2_id = "player-2-#{System.unique_integer([:positive])}"
      player3_id = "player-3-#{System.unique_integer([:positive])}"

      {:ok, _, socket1} =
        CountryguessrWeb.UserSocket
        |> socket("user_id", %{player_id: player1_id})
        |> subscribe_and_join(
          CountryguessrWeb.GameChannel,
          "game:#{new_game_id}",
          %{"nickname" => "Player1", "player_id" => player1_id}
        )

      {:ok, _, _socket2} =
        CountryguessrWeb.UserSocket
        |> socket("user_id", %{player_id: player2_id})
        |> subscribe_and_join(
          CountryguessrWeb.GameChannel,
          "game:#{new_game_id}",
          %{"nickname" => "Player2", "player_id" => player2_id}
        )

      {:ok, _, _socket3} =
        CountryguessrWeb.UserSocket
        |> socket("user_id", %{player_id: player3_id})
        |> subscribe_and_join(
          CountryguessrWeb.GameChannel,
          "game:#{new_game_id}",
          %{"nickname" => "Player3", "player_id" => player3_id}
        )

      # Start game
      ref = push(socket1, "start_game", %{})
      assert_reply ref, :ok
      assert_push "game_started", _

      # Exhaust player1's lives
      for _ <- 1..3 do
        ref =
          push(socket1, "submit_guess", %{"clicked_country" => "US", "guessed_country" => "FR"})

        assert_reply ref, :ok, _
        assert_push "life_lost", _
      end

      # Drain player_eliminated push
      assert_push "player_eliminated", _

      ref = push(socket1, "submit_guess", %{"clicked_country" => "US", "guessed_country" => "US"})
      assert_reply ref, :error, %{reason: :player_eliminated}
    end

    test "rejects invalid country codes", %{socket: socket} do
      ref = push(socket, "submit_guess", %{"clicked_country" => "USA", "guessed_country" => "FR"})
      assert_reply ref, :error, %{reason: :invalid_country_code}
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
end

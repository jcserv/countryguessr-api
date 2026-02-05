defmodule Countryguessr.RateLimiterTest do
  use ExUnit.Case, async: false

  alias Countryguessr.RateLimiter

  setup do
    # Ensure rate limiter is started
    case Process.whereis(RateLimiter) do
      nil ->
        {:ok, _pid} = RateLimiter.start_link()

      _pid ->
        :ok
    end

    # Clear any existing data before each test
    RateLimiter.clear_all()
    :ok
  end

  describe "check/3" do
    test "allows first request" do
      player_id = "player-#{System.unique_integer()}"
      assert :ok = RateLimiter.check(player_id, :claim_country)
    end

    test "allows requests within limit" do
      player_id = "player-#{System.unique_integer()}"

      for _ <- 1..5 do
        assert :ok = RateLimiter.check(player_id, :claim_country)
      end
    end

    test "blocks requests exceeding limit" do
      player_id = "player-#{System.unique_integer()}"

      # Exhaust the limit (default is 10)
      for _ <- 1..10 do
        assert :ok = RateLimiter.check(player_id, :claim_country)
      end

      # 11th request should be blocked
      assert {:error, :rate_limited} = RateLimiter.check(player_id, :claim_country)
    end

    test "respects custom max_requests option" do
      player_id = "player-#{System.unique_integer()}"

      # Set a low limit
      for _ <- 1..3 do
        assert :ok = RateLimiter.check(player_id, :claim_country, max_requests: 3)
      end

      assert {:error, :rate_limited} =
               RateLimiter.check(player_id, :claim_country, max_requests: 3)
    end

    test "resets after window expires" do
      player_id = "player-#{System.unique_integer()}"

      # Use a very short window
      window_ms = 50

      # Exhaust the limit
      for _ <- 1..3 do
        assert :ok = RateLimiter.check(player_id, :claim_country, max_requests: 3, window_ms: window_ms)
      end

      assert {:error, :rate_limited} =
               RateLimiter.check(player_id, :claim_country, max_requests: 3, window_ms: window_ms)

      # Wait for window to expire
      Process.sleep(window_ms + 10)

      # Should be allowed again
      assert :ok = RateLimiter.check(player_id, :claim_country, max_requests: 3, window_ms: window_ms)
    end

    test "tracks different actions separately" do
      player_id = "player-#{System.unique_integer()}"

      # Exhaust limit for one action
      for _ <- 1..3 do
        assert :ok = RateLimiter.check(player_id, :action_a, max_requests: 3)
      end

      assert {:error, :rate_limited} = RateLimiter.check(player_id, :action_a, max_requests: 3)

      # Different action should still be allowed
      assert :ok = RateLimiter.check(player_id, :action_b, max_requests: 3)
    end

    test "tracks different players separately" do
      player_a = "player-a-#{System.unique_integer()}"
      player_b = "player-b-#{System.unique_integer()}"

      # Exhaust limit for player A
      for _ <- 1..3 do
        assert :ok = RateLimiter.check(player_a, :claim_country, max_requests: 3)
      end

      assert {:error, :rate_limited} = RateLimiter.check(player_a, :claim_country, max_requests: 3)

      # Player B should still be allowed
      assert :ok = RateLimiter.check(player_b, :claim_country, max_requests: 3)
    end
  end

  describe "clear/1" do
    test "clears rate limit data for a player" do
      player_id = "player-#{System.unique_integer()}"

      # Exhaust the limit
      for _ <- 1..3 do
        RateLimiter.check(player_id, :claim_country, max_requests: 3)
      end

      assert {:error, :rate_limited} =
               RateLimiter.check(player_id, :claim_country, max_requests: 3)

      # Clear the player's data
      assert :ok = RateLimiter.clear(player_id)

      # Should be allowed again
      assert :ok = RateLimiter.check(player_id, :claim_country, max_requests: 3)
    end

    test "only clears data for the specified player" do
      player_a = "player-a-#{System.unique_integer()}"
      player_b = "player-b-#{System.unique_integer()}"

      # Exhaust limits for both players
      for _ <- 1..3 do
        RateLimiter.check(player_a, :claim_country, max_requests: 3)
        RateLimiter.check(player_b, :claim_country, max_requests: 3)
      end

      # Clear only player A
      RateLimiter.clear(player_a)

      # Player A should be allowed, B should still be limited
      assert :ok = RateLimiter.check(player_a, :claim_country, max_requests: 3)
      assert {:error, :rate_limited} = RateLimiter.check(player_b, :claim_country, max_requests: 3)
    end
  end

  describe "clear_all/0" do
    test "clears all rate limit data" do
      player_a = "player-a-#{System.unique_integer()}"
      player_b = "player-b-#{System.unique_integer()}"

      # Exhaust limits for both players
      for _ <- 1..3 do
        RateLimiter.check(player_a, :claim_country, max_requests: 3)
        RateLimiter.check(player_b, :claim_country, max_requests: 3)
      end

      # Clear all
      assert :ok = RateLimiter.clear_all()

      # Both should be allowed
      assert :ok = RateLimiter.check(player_a, :claim_country, max_requests: 3)
      assert :ok = RateLimiter.check(player_b, :claim_country, max_requests: 3)
    end
  end
end

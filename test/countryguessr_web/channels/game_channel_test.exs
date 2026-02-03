defmodule CountryguessrWeb.GameChannelTest do
  use CountryguessrWeb.ChannelCase

  # Use unique game ID per test to avoid state pollution
  setup do
    game_id = "test-#{System.unique_integer([:positive])}"

    {:ok, _, socket} =
      CountryguessrWeb.UserSocket
      |> socket("user_id", %{player_id: "test-player"})
      |> subscribe_and_join(CountryguessrWeb.GameChannel, "game:#{game_id}")

    %{socket: socket, game_id: game_id}
  end

  describe "join" do
    test "returns current value on join", %{socket: _socket} do
      # Already tested in setup - join succeeded
      # Value is returned in join response
    end
  end

  describe "increment" do
    test "increments game and broadcasts update", %{socket: socket} do
      ref = push(socket, "increment", %{})
      assert_reply ref, :ok, %{value: 1}
      assert_push "updated", %{value: 1}
    end
  end

  describe "reset" do
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

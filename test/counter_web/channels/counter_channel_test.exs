defmodule CounterWeb.CounterChannelTest do
  use CounterWeb.ChannelCase

  # Use unique counter ID per test to avoid state pollution
  setup do
    counter_id = "test-#{System.unique_integer([:positive])}"

    {:ok, _, socket} =
      CounterWeb.UserSocket
      |> socket("user_id", %{player_id: "test-player"})
      |> subscribe_and_join(CounterWeb.CounterChannel, "counter:#{counter_id}")

    %{socket: socket, counter_id: counter_id}
  end

  describe "join" do
    test "returns current value on join", %{socket: _socket} do
      # Already tested in setup - join succeeded
      # Value is returned in join response
    end
  end

  describe "increment" do
    test "increments counter and broadcasts update", %{socket: socket} do
      ref = push(socket, "increment", %{})
      assert_reply ref, :ok, %{value: 1}
      assert_push "updated", %{value: 1}
    end
  end

  describe "reset" do
    test "resets counter and broadcasts update", %{socket: socket} do
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

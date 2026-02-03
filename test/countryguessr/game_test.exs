defmodule Countryguessr.GameTest do
  use ExUnit.Case, async: true

  alias Countryguessr.Game

  describe "Game context" do
    test "increment creates game if it doesn't exist" do
      id = "test-#{System.unique_integer()}"
      assert {:ok, 1} = Game.increment(id)
      assert {:ok, 2} = Game.increment(id)
    end

    test "get returns error for non-existent game" do
      id = "nonexistent-#{System.unique_integer()}"
      assert {:error, :not_found} = Game.get(id)
    end

    test "reset sets game to 0" do
      id = "test-#{System.unique_integer()}"
      Game.increment(id)
      Game.increment(id)
      assert {:ok, 0} = Game.reset(id)
    end

    test "decrement works" do
      id = "test-#{System.unique_integer()}"
      Game.increment(id)
      assert {:ok, 0} = Game.decrement(id)
      assert {:ok, -1} = Game.decrement(id)
    end
  end
end

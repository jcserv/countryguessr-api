defmodule CounterTest do
  use ExUnit.Case, async: true

  describe "Counter context" do
    test "increment creates counter if it doesn't exist" do
      id = "test-#{System.unique_integer()}"
      assert {:ok, 1} = Counter.increment(id)
      assert {:ok, 2} = Counter.increment(id)
    end

    test "get returns error for non-existent counter" do
      id = "nonexistent-#{System.unique_integer()}"
      assert {:error, :not_found} = Counter.get(id)
    end

    test "reset sets counter to 0" do
      id = "test-#{System.unique_integer()}"
      Counter.increment(id)
      Counter.increment(id)
      assert {:ok, 0} = Counter.reset(id)
    end

    test "decrement works" do
      id = "test-#{System.unique_integer()}"
      Counter.increment(id)
      assert {:ok, 0} = Counter.decrement(id)
      assert {:ok, -1} = Counter.decrement(id)
    end
  end
end

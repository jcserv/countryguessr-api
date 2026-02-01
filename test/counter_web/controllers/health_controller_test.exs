defmodule CounterWeb.HealthControllerTest do
  use CounterWeb.ConnCase

  describe "GET /health" do
    test "returns ok status", %{conn: conn} do
      conn = get(conn, "/health")
      assert %{"status" => "ok"} = json_response(conn, 200)
    end
  end
end

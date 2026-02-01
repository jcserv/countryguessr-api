defmodule CounterWeb.CounterControllerTest do
  use CounterWeb.ConnCase

  describe "GET /api/counters/:id" do
    test "returns 0 for non-existent counter", %{conn: conn} do
      id = "test-#{System.unique_integer()}"
      conn = get(conn, "/api/counters/#{id}")
      assert %{"id" => ^id, "value" => 0} = json_response(conn, 200)
    end
  end

  describe "POST /api/counters/:id/increment" do
    test "increments the counter", %{conn: conn} do
      id = "test-#{System.unique_integer()}"

      conn = post(conn, "/api/counters/#{id}/increment")
      assert %{"id" => ^id, "value" => 1} = json_response(conn, 200)

      conn = build_conn()
      conn = post(conn, "/api/counters/#{id}/increment")
      assert %{"id" => ^id, "value" => 2} = json_response(conn, 200)
    end
  end

  describe "POST /api/counters/:id/reset" do
    test "resets the counter to 0", %{conn: conn} do
      id = "test-#{System.unique_integer()}"

      post(conn, "/api/counters/#{id}/increment")
      post(build_conn(), "/api/counters/#{id}/increment")

      conn = build_conn()
      conn = post(conn, "/api/counters/#{id}/reset")
      assert %{"id" => ^id, "value" => 0} = json_response(conn, 200)
    end
  end
end

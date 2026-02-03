defmodule CountryguessrWeb.GameControllerTest do
  use CountryguessrWeb.ConnCase

  describe "GET /api/games/:id" do
    test "returns 0 for non-existent game", %{conn: conn} do
      id = "test-#{System.unique_integer()}"
      conn = get(conn, "/api/games/#{id}")
      assert %{"id" => ^id, "value" => 0} = json_response(conn, 200)
    end
  end

  describe "POST /api/games/:id/increment" do
    test "increments the game", %{conn: conn} do
      id = "test-#{System.unique_integer()}"

      conn = post(conn, "/api/games/#{id}/increment")
      assert %{"id" => ^id, "value" => 1} = json_response(conn, 200)

      conn = build_conn()
      conn = post(conn, "/api/games/#{id}/increment")
      assert %{"id" => ^id, "value" => 2} = json_response(conn, 200)
    end
  end

  describe "POST /api/games/:id/reset" do
    test "resets the game to 0", %{conn: conn} do
      id = "test-#{System.unique_integer()}"

      post(conn, "/api/games/#{id}/increment")
      post(build_conn(), "/api/games/#{id}/increment")

      conn = build_conn()
      conn = post(conn, "/api/games/#{id}/reset")
      assert %{"id" => ^id, "value" => 0} = json_response(conn, 200)
    end
  end
end

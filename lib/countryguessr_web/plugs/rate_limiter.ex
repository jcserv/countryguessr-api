defmodule CountryguessrWeb.Plugs.RateLimiter do
  @moduledoc """
  Rate limiting plug using Hammer.

  Limits requests by client IP address to prevent abuse.

  ## Configuration

  - General API: 100 requests per minute
  - Game creation: 10 requests per minute (more restrictive)
  """
  import Plug.Conn

  @behaviour Plug

  # Requests per minute
  @general_limit 100
  @create_game_limit 10
  @window_ms 60_000

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    client_ip = get_client_ip(conn)

    {limit, bucket_name} = get_limit_for_request(conn, client_ip)

    case Hammer.check_rate(bucket_name, @window_ms, limit) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(429, Jason.encode!(%{error: "Rate limit exceeded. Try again later."}))
        |> halt()
    end
  end

  defp get_limit_for_request(conn, client_ip) do
    # More restrictive limit for game creation
    if conn.method == "POST" and conn.request_path == "/api/games" do
      {@create_game_limit, "create_game:#{client_ip}"}
    else
      {@general_limit, "general:#{client_ip}"}
    end
  end

  defp get_client_ip(conn) do
    # Check for forwarded IP (when behind proxy/load balancer like Cloudflare or Fly.io)
    forwarded_for =
      conn
      |> get_req_header("x-forwarded-for")
      |> List.first()

    case forwarded_for do
      nil ->
        conn.remote_ip |> :inet.ntoa() |> to_string()

      forwarded ->
        # x-forwarded-for can contain multiple IPs, take the first (original client)
        forwarded
        |> String.split(",")
        |> List.first()
        |> String.trim()
    end
  end
end

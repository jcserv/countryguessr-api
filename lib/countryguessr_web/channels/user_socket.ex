defmodule CountryguessrWeb.UserSocket do
  use Phoenix.Socket

  @moduledoc """
  WebSocket entry point.

  Clients connect here and then join specific channels.

  ## Connection

  Connect with a player_id (client-generated UUID):

      const socket = new Phoenix.Socket("/socket", {
        params: { player_id: "uuid-here" }
      });

  The player_id is optional - if not provided, one is generated server-side.
  """

  # Channels
  channel "game:*", CountryguessrWeb.GameChannel

  @impl true
  def connect(params, socket, _connect_info) do
    # Accept player_id from client or generate one
    player_id = Map.get(params, "player_id") || generate_id()

    socket =
      socket
      |> assign(:player_id, player_id)

    {:ok, socket}
  end

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.player_id}"

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end

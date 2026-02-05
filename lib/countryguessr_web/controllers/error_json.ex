defmodule CountryguessrWeb.ErrorJSON do
  @moduledoc """
  JSON error responses with standardized error codes.
  """

  @doc """
  Renders an error response with an error code and message.
  """
  def render("error.json", %{reason: reason}) do
    %{
      error: %{
        code: error_code(reason),
        message: error_message(reason)
      }
    }
  end

  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end

  # Error codes for game-related errors
  defp error_code(:invalid_country_code), do: "INVALID_COUNTRY_CODE"
  defp error_code(:already_claimed), do: "ALREADY_CLAIMED"
  defp error_code(:game_not_playing), do: "GAME_NOT_PLAYING"
  defp error_code(:game_not_in_lobby), do: "GAME_NOT_IN_LOBBY"
  defp error_code(:game_already_started), do: "GAME_ALREADY_STARTED"
  defp error_code(:not_in_game), do: "NOT_IN_GAME"
  defp error_code(:not_host), do: "NOT_HOST"
  defp error_code(:not_enough_players), do: "NOT_ENOUGH_PLAYERS"
  defp error_code(:not_found), do: "NOT_FOUND"
  defp error_code(:rate_limited), do: "RATE_LIMITED"
  defp error_code(:unknown_event), do: "UNKNOWN_EVENT"
  defp error_code(_), do: "UNKNOWN_ERROR"

  # Human-readable error messages
  defp error_message(:invalid_country_code), do: "Invalid country code format"
  defp error_message(:already_claimed), do: "This country has already been claimed"
  defp error_message(:game_not_playing), do: "The game is not currently in progress"
  defp error_message(:game_not_in_lobby), do: "The game is not in the lobby"
  defp error_message(:game_already_started), do: "The game has already started"
  defp error_message(:not_in_game), do: "You are not in this game"
  defp error_message(:not_host), do: "Only the host can perform this action"
  defp error_message(:not_enough_players), do: "Not enough players to start"
  defp error_message(:not_found), do: "Game not found"
  defp error_message(:rate_limited), do: "Too many requests, please slow down"
  defp error_message(:unknown_event), do: "Unknown event"
  defp error_message(_), do: "An unknown error occurred"
end

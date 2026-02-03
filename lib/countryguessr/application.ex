defmodule Countryguessr.Application do
  @moduledoc """
  OTP Application supervision tree.

  Starts:
  - Registry for looking up game processes by ID
  - DynamicSupervisor for spawning game processes on demand
  - Phoenix PubSub for broadcasting updates
  - Web endpoint
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Game process registry - allows lookup by game_id
      {Registry, keys: :unique, name: Countryguessr.Registry},

      # Dynamic supervisor for game processes
      {DynamicSupervisor, strategy: :one_for_one, name: Countryguessr.DynamicSupervisor},

      # PubSub for broadcasting game updates
      {Phoenix.PubSub, name: Countryguessr.PubSub},

      # Web endpoint
      CountryguessrWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Countryguessr.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    CountryguessrWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

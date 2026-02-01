defmodule Counter.Application do
  @moduledoc """
  OTP Application supervision tree.

  Starts:
  - Registry for looking up counter processes by ID
  - DynamicSupervisor for spawning counter processes on demand
  - Phoenix PubSub for broadcasting updates
  - Web endpoint
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Counter process registry - allows lookup by counter_id
      {Registry, keys: :unique, name: Counter.Registry},

      # Dynamic supervisor for counter processes
      {DynamicSupervisor, strategy: :one_for_one, name: Counter.DynamicSupervisor},

      # PubSub for broadcasting counter updates
      {Phoenix.PubSub, name: Counter.PubSub},

      # Web endpoint
      CounterWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Counter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    CounterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

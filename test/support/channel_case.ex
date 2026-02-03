defmodule CountryguessrWeb.ChannelCase do
  @moduledoc """
  Test case for channel tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import CountryguessrWeb.ChannelCase

      @endpoint CountryguessrWeb.Endpoint
    end
  end

  setup _tags do
    :ok
  end
end

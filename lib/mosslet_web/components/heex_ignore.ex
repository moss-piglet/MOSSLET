defmodule MossletWeb.Components.HeexIgnore do
  @moduledoc """
  A function component to comment out heex code.
  """
  use Phoenix.Component

  def ignore(assigns), do: ~H""
end

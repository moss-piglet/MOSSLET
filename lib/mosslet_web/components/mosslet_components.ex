defmodule MossletComponents do
  @moduledoc false
  defmacro __using__(_) do
    quote do
      import MossletWeb.Flash
      import MossletWeb.LocalTime
      import MossletWeb.PageComponents
      import MossletWeb.PublicLayout
    end
  end
end

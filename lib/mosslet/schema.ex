defmodule Mosslet.Schema do
  @moduledoc """
  Use this in every schema file.
  """
  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      use QueryBuilder

      import Ecto.Changeset
    end
  end
end

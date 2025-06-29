defmodule Mosslet.Extensions.Ecto.RepoExt do
  @moduledoc """
  Extend Repo with some useful functions.
  Add this line to your repo:

      use Mosslet.Extensions.Ecto.RepoExt
  """

  defmacro __using__(_) do
    quote do
      import Ecto.Query

      @doc """
      Retrieves the last object in the database given a schema module.
      user = Repo.last(User)
      """
      def last(model_or_query) do
        __MODULE__.one(from(x in model_or_query, order_by: [desc: x.id], limit: 1))
      end

      @doc """
      Retrieves the first object in the database given a schema module.
      comment = Repo.first(Comment)
      """
      def first(model_or_query, preload \\ []) do
        __MODULE__.one(
          from(x in model_or_query, order_by: [asc: x.id], limit: 1, preload: ^preload)
        )
      end

      @doc """
      Pass in a queryable and this will count how many are in the database as opposed to fetching them
      user_count = Repo.count(User)
      """
      def count(model_or_query) do
        __MODULE__.one(from(p in model_or_query, select: count()))
      end
    end
  end
end

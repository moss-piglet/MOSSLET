defmodule Mosslet.Journal.JournalInsight do
  @moduledoc """
  Cached AI-generated mood insight for a user's journal entries.

  Rate-limited to once per 24h manual refresh, auto-refreshes weekly.
  The insight text is encrypted with the user's personal key.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "journal_insights" do
    field :insight, Encrypted.Binary
    field :generated_at, :utc_datetime_usec

    belongs_to :user, User

    timestamps()
  end

  def changeset(insight, attrs, opts \\ []) do
    insight
    |> cast(attrs, [:insight, :generated_at, :user_id])
    |> validate_required([:insight, :generated_at, :user_id])
    |> unique_constraint(:user_id)
    |> encrypt_insight(opts)
  end

  defp encrypt_insight(changeset, opts) do
    if changeset.valid? && opts[:user] && opts[:key] do
      if insight_text = get_change(changeset, :insight) do
        encrypted = Encrypted.Users.Utils.encrypt_user_data(insight_text, opts[:user], opts[:key])
        put_change(changeset, :insight, encrypted)
      else
        changeset
      end
    else
      changeset
    end
  end
end

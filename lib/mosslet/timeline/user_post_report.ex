defmodule Mosslet.Timeline.UserPostReport do
  @moduledoc """
  Junction table storing encrypted report keys for admin access.

  Follows the same pattern as UserPost - stores the report_key encrypted 
  with server public key for admin access to report content.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Encrypted
  alias Mosslet.Timeline.PostReport

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_post_reports" do
    # The report key encrypted with server public key for admin access
    field :key, Encrypted.Binary

    # Relationship to the report
    belongs_to :post_report, PostReport

    timestamps()
  end

  @doc """
  Creates changeset for user post report key with server-key encryption.
  """
  def changeset(user_post_report, attrs, opts \\ []) do
    user_post_report
    |> cast(attrs, [:post_report_id])
    |> validate_required([:post_report_id])
    |> encrypt_report_key(opts)
  end

  # Encrypt report key with server public key for admin access
  defp encrypt_report_key(changeset, opts) do
    if changeset.valid? && opts[:report_key] do
      # Get server public key for admin-accessible encryption
      server_public_key = Application.get_env(:mosslet, :server_public_key)

      case Mosslet.Encrypted.Utils.encrypt_message_for_user_with_pk(
             opts[:report_key],
             %{public: server_public_key}
           ) do
        encrypted_key when is_binary(encrypted_key) ->
          put_change(changeset, :key, encrypted_key)

        _error ->
          add_error(changeset, :key, "Failed to encrypt report key for admin access")
      end
    else
      changeset
    end
  end
end

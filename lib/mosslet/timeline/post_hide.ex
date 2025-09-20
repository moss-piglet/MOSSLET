defmodule Mosslet.Timeline.PostHide do
  @moduledoc """
  A post hide represents a user hiding a specific post.

  Uses enacl encryption for user-generated preference data:
  - Reason encrypted with user's own key (personal preference)
  - Hide type for different levels of hiding
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Encrypted
  alias Mosslet.Accounts.User
  alias Mosslet.Timeline.Post

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "post_hides" do
    # ENCRYPTED FIELDS (user preference data - use enacl with user keys)
    # Why they hid it (enacl encrypted)
    field :reason, Encrypted.Binary

    # PLAINTEXT FIELDS (system data)
    field :hide_type, Ecto.Enum,
      values: [:post, :user_posts, :similar_content],
      default: :post

    # RELATIONSHIPS
    # User who hid the post
    belongs_to :user, User
    # Post being hidden
    belongs_to :post, Post

    timestamps()
  end

  @doc """
  Creates changeset for post hide with user-key encryption.

  ## Examples

      iex> PostHide.changeset(%PostHide{}, %{
      ...>   reason: "Not interested in this topic",
      ...>   hide_type: :similar_content
      ...> }, user: user, user_key: user_key)
  """
  def changeset(hide, attrs, opts \\ []) do
    hide
    |> cast(attrs, [:reason, :hide_type, :user_id, :post_id])
    |> validate_required([:user_id, :post_id])
    |> encrypt_user_data(opts)
    |> unique_constraint([:user_id, :post_id],
      message: "You have already hidden this post"
    )
  end

  # Encrypt reason with user's own encryption key
  defp encrypt_user_data(changeset, opts) do
    if changeset.valid? && opts[:user] && opts[:user_key] do
      reason = get_field(changeset, :reason)

      if reason && String.trim(reason) != "" do
        # Generate a unique key for this hide
        hide_key = Mosslet.Encrypted.Utils.generate_key()

        encrypted_reason =
          Mosslet.Encrypted.Utils.encrypt(%{
            key: hide_key,
            payload: String.trim(reason)
          })

        put_change(changeset, :reason, encrypted_reason)
      else
        changeset
      end
    else
      changeset
    end
  end
end

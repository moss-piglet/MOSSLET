defmodule Mosslet.Timeline.PostReport do
  @moduledoc """
  A post report represents a user reporting harmful content.

  Uses enacl encryption for user-generated sensitive data:
  - Reason and details encrypted with user keys (personal, sensitive)
  - Reason hash for admin searching/categorization
  - Status tracking for moderation workflow
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Timeline.Post

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "post_reports" do
    # ENCRYPTED FIELDS (user-generated sensitive data - use enacl with user keys)
    # Report reason (enacl encrypted)
    field :reason, :binary
    # Additional details (enacl encrypted)
    field :details, :binary

    # HASHED FIELDS (for admin searching/filtering - use Cloak)
    # Searchable hash for categorizing reports
    field :reason_hash, Mosslet.Encrypted.HMAC

    # PLAINTEXT FIELDS (system data for moderation workflow)
    field :status, Ecto.Enum,
      values: [:pending, :reviewed, :resolved, :dismissed],
      default: :pending

    field :severity, Ecto.Enum,
      values: [:low, :medium, :high, :critical],
      default: :low

    field :report_type, Ecto.Enum,
      values: [:content, :harassment, :spam, :other],
      default: :content

    # RELATIONSHIPS
    # User who reported
    belongs_to :reporter, User, foreign_key: :reporter_id
    # User being reported
    belongs_to :reported_user, User, foreign_key: :reported_user_id
    # Post being reported
    belongs_to :post, Post

    timestamps()
  end

  @doc """
  Creates changeset for post report with user-key encryption.

  ## Examples

      iex> PostReport.changeset(%PostReport{}, %{
      ...>   reason: "harassment",
      ...>   details: "This post contains threatening language",
      ...>   report_type: :harassment,
      ...>   severity: :high
      ...> }, user: reporter, user_key: user_key)
  """
  def changeset(report, attrs, opts \\ []) do
    report
    |> cast(attrs, [
      :reason,
      :details,
      :status,
      :severity,
      :report_type,
      :reporter_id,
      :reported_user_id,
      :post_id
    ])
    |> validate_required([:reason, :report_type, :reporter_id, :reported_user_id, :post_id])
    |> validate_length(:reason, min: 1, max: 100)
    |> validate_length(:details, max: 1000)
    |> encrypt_user_data(opts)
    |> unique_constraint([:reporter_id, :post_id],
      name: :post_reports_reporter_post_index,
      message: "You have already reported this post"
    )
  end

  # Encrypt reason and details with user's own encryption key
  defp encrypt_user_data(changeset, opts) do
    if changeset.valid? && opts[:user] && opts[:user_key] do
      reason = get_field(changeset, :reason)
      details = get_field(changeset, :details)

      # Generate a unique key for this report
      report_key = Mosslet.Encrypted.Utils.generate_key()

      changeset =
        if reason && String.trim(reason) != "" do
          encrypted_reason =
            Mosslet.Encrypted.Utils.encrypt(%{
              key: report_key,
              payload: String.trim(reason)
            })

          changeset
          |> put_change(:reason, encrypted_reason)
          |> put_change(:reason_hash, String.downcase(String.trim(reason)))
        else
          changeset
        end

      if details && String.trim(details) != "" do
        encrypted_details =
          Mosslet.Encrypted.Utils.encrypt(%{
            key: report_key,
            payload: String.trim(details)
          })

        put_change(changeset, :details, encrypted_details)
      else
        changeset
      end
    else
      changeset
    end
  end
end

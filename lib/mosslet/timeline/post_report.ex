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

  alias Mosslet.Encrypted
  alias Mosslet.Accounts.User
  alias Mosslet.Timeline.{Post, Reply, UserPostReport}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "post_reports" do
    # ENCRYPTED FIELDS (user-generated sensitive data - use enacl with user keys)
    # Report reason (enacl encrypted)
    field :reason, Encrypted.Binary
    # Additional details (enacl encrypted)
    field :details, Encrypted.Binary

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

    # ADMIN ACTION TRACKING FIELDS
    # Admin reasoning (encrypted with server public key)
    field :admin_notes, Encrypted.Binary
    # Admin notes hash for searching
    field :admin_notes_hash, Mosslet.Encrypted.HMAC
    # Admin action taken
    field :admin_action, Ecto.Enum,
      values: [:none, :warning, :content_deleted, :user_suspended],
      default: :none

    # Severity score (1-5)
    field :severity_score, :integer, default: 1
    # Admin action timestamp
    field :admin_action_at, :utc_datetime
    # Score impacts for improved algorithms
    field :reporter_score_impact, :integer, default: 0
    field :reported_user_score_impact, :integer, default: 0
    # Content deletion tracking flags
    field :post_deleted?, :boolean, default: false
    field :reply_deleted?, :boolean, default: false

    # RELATIONSHIPS
    # User who reported
    belongs_to :reporter, User, foreign_key: :reporter_id
    # User being reported
    belongs_to :reported_user, User, foreign_key: :reported_user_id
    # Post being reported (nullable for audit trail when posts are deleted)
    belongs_to :post, Post, foreign_key: :post_id
    # Reply being reported (optional - when reporting a specific reply, nullable for audit trail)
    belongs_to :reply, Reply, foreign_key: :reply_id
    # Admin who took action
    belongs_to :admin_user, User, foreign_key: :admin_user_id

    # UserPostReport
    has_one :user_post_report, UserPostReport

    timestamps()
  end

  @doc """
  Creates changeset for admin action updates with proper encryption.

  Admin notes are encrypted with server public key for admin-only access.
  Follows the same security pattern as the original report content.
  """
  def admin_action_changeset(report, attrs, opts \\ []) do
    report
    |> cast(attrs, [
      :status,
      :admin_action,
      :admin_notes,
      :severity_score,
      :admin_user_id,
      :reporter_score_impact,
      :reported_user_score_impact,
      :post_deleted?,
      :reply_deleted?
    ])
    |> validate_inclusion(:severity_score, 1..5)
    |> validate_length(:admin_notes, max: 500)
    |> put_change(:admin_action_at, DateTime.utc_now() |> DateTime.truncate(:second))
    |> encrypt_admin_notes(opts)
    |> calculate_score_impacts()
  end

  @doc """
  Creates changeset for post report with proper asymmetric encryption.

  This follows the same pattern as Posts:
  1. Generate unique report_key
  2. Encrypt content with report_key
  3. Create UserPostReport with report_key encrypted for admin access

  ## Examples

      iex> PostReport.changeset(%PostReport{}, %{
      ...>   reason: "harassment",
      ...>   details: "This post contains threatening language",
      ...>   report_type: :harassment,
      ...>   severity: :high
      ...> }, report_key: report_key)
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
      :post_id,
      :reply_id,
      :admin_notes,
      :admin_action,
      :severity_score,
      :admin_user_id
    ])
    |> validate_required([:reason, :report_type, :reporter_id, :reported_user_id])
    |> validate_length(:reason, min: 1, max: 100)
    |> validate_length(:details, max: 1000)
    |> validate_reply_belongs_to_post()
    |> encrypt_report_content(opts)
    |> unique_constraint([:reporter_id, :post_id],
      name: :post_reports_reporter_post_index,
      message: "You have already reported this post"
    )
    |> unique_constraint([:reporter_id, :reply_id],
      name: :post_reports_reporter_reply_index,
      message: "You have already reported this reply"
    )
  end

  # Validates that if reply_id is present, it belongs to the specified post
  defp validate_reply_belongs_to_post(changeset) do
    post_id = get_field(changeset, :post_id)
    reply_id = get_field(changeset, :reply_id)

    if post_id && reply_id do
      # Check if the reply belongs to the post
      case Mosslet.Repo.get(Mosslet.Timeline.Reply, reply_id) do
        %{post_id: ^post_id} ->
          changeset

        %{post_id: _other_post_id} ->
          add_error(changeset, :reply_id, "Reply does not belong to the specified post")

        nil ->
          add_error(changeset, :reply_id, "Reply not found")
      end
    else
      changeset
    end
  end

  # Encrypt reason and details with report_key (consistent with Posts pattern)
  defp encrypt_report_content(changeset, opts) do
    if changeset.valid? && opts[:report_key] do
      reason = get_field(changeset, :reason)
      details = get_field(changeset, :details)
      report_key = opts[:report_key]

      changeset =
        if reason && String.trim(reason) != "" do
          encrypted_reason =
            Mosslet.Encrypted.Utils.encrypt(%{key: report_key, payload: String.trim(reason)})

          changeset
          |> put_change(:reason, encrypted_reason)
          |> put_change(:reason_hash, String.downcase(String.trim(reason)))
        else
          changeset
        end

      if details && String.trim(details) != "" do
        encrypted_details =
          Mosslet.Encrypted.Utils.encrypt(%{key: report_key, payload: String.trim(details)})

        put_change(changeset, :details, encrypted_details)
      else
        changeset
      end
    else
      changeset
    end
  end

  # Encrypt admin notes with server public key for admin access
  defp encrypt_admin_notes(changeset, _opts) do
    if changeset.valid? do
      admin_notes = get_field(changeset, :admin_notes)

      if admin_notes && String.trim(admin_notes) != "" do
        # Get server public key for admin-accessible encryption
        server_public_key = Application.get_env(:mosslet, :server_public_key)

        encrypted_notes =
          Mosslet.Encrypted.Utils.encrypt_message_for_user_with_pk(
            String.trim(admin_notes),
            %{public: server_public_key}
          )

        changeset
        |> put_change(:admin_notes, encrypted_notes)
        |> put_change(:admin_notes_hash, String.downcase(String.trim(admin_notes)))
      else
        changeset
      end
    else
      changeset
    end
  end

  # Calculate score impacts based on admin action and status
  defp calculate_score_impacts(changeset) do
    if changeset.valid? do
      status = get_field(changeset, :status)
      admin_action = get_field(changeset, :admin_action)
      severity_score = get_field(changeset, :severity_score) || 1

      {reporter_impact, reported_user_impact} =
        case {status, admin_action} do
          {:dismissed, _} ->
            # Dismissed = bad for reporter, good for reported user
            {-2, 1}

          {:resolved, :none} ->
            # Resolved without action = mild positive for reporter
            {1, -1}

          {:resolved, :warning} ->
            # Warning given = positive for reporter, mild negative for user
            {2, -2}

          {:resolved, :content_deleted} ->
            # Content deleted = strong positive for reporter, negative for user (scaled by severity)
            {3 + severity_score, -(3 + severity_score)}

          {:resolved, :user_suspended} ->
            # User suspended = very strong impact
            {5 + severity_score, -(5 + severity_score)}

          _ ->
            # Pending/reviewed = no impact yet
            {0, 0}
        end

      changeset
      |> put_change(:reporter_score_impact, reporter_impact)
      |> put_change(:reported_user_score_impact, reported_user_impact)
    else
      changeset
    end
  end
end

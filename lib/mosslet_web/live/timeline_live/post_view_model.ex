defmodule MossletWeb.TimelineLive.PostViewModel do
  @moduledoc """
  View-model for the timeline post card (`MossletWeb.TimelineComponents.liquid_timeline_post`).

  Every post card rendered by `MossletWeb.TimelineLive.Index` needs the same set
  of per-post, per-viewer fields resolved: the author's display name, avatar, and
  profile link, plus the sealed payloads the browser-side ZK hooks decrypt, plus
  the viewer-specific bookmark/unread state. Previously the template invoked ~8
  separate `get_post_*` helpers per card (twice — once in the unread stream and
  once in the read stream), spreading that resolution logic across the LiveView.

  This module concentrates that resolution into a single, testable struct built
  once per card via `build/3`. It performs **no** new decryption: each field is
  resolved through the exact same `MossletWeb.Helpers` / `Mosslet.Accounts` /
  `Mosslet.Orgs` / `Mosslet.Timeline` calls the inline helpers used, so the
  zero-knowledge invariants are unchanged:

    * `user_name` is the server-known display value (own/public) or `"..."`
      placeholder that the browser `DecryptPost` hook overwrites for non-public
      posts.
    * `encrypted_author_name_data` / `encrypted_avatar_data` are the **sealed**
      payloads handed to the browser hooks — returned exactly as before.

  Mirrors `MossletWeb.UserHomeLive.ProfileViewModel`.
  """

  alias Mosslet.Accounts
  alias Mosslet.Orgs
  alias Mosslet.Timeline
  alias MossletWeb.Helpers

  @type t :: %__MODULE__{
          user_name: String.t(),
          encrypted_author_name_data: map() | nil,
          user_avatar: String.t(),
          encrypted_avatar_data: term() | nil,
          author_profile_slug: String.t() | nil,
          author_profile_visibility: atom() | nil,
          bookmarked?: boolean(),
          unread?: boolean(),
          peer_user_id: String.t() | nil,
          peer_public_key: String.t() | nil,
          peer_pq_public_key: String.t() | nil,
          sealed_peer_pin: String.t() | nil
        }

  defstruct user_name: "...",
            encrypted_author_name_data: nil,
            user_avatar: "/images/logo.svg",
            encrypted_avatar_data: nil,
            author_profile_slug: nil,
            author_profile_visibility: nil,
            bookmarked?: false,
            unread?: false,
            peer_user_id: nil,
            peer_public_key: nil,
            peer_pq_public_key: nil,
            sealed_peer_pin: nil

  @doc """
  Builds the post view-model for a given post and viewing user.

    * `post`         — the post being rendered (with `:decrypted` populated).
    * `current_user` — the viewing (session) user.
    * `key`          — the viewer's session key (used for the guardian-safety
      avatar override path only).
  """
  @spec build(post :: struct(), current_user :: struct(), key :: binary()) :: t()
  def build(post, current_user, key) do
    verification = verification(post, current_user)

    %__MODULE__{
      user_name: author_name(post, current_user),
      encrypted_author_name_data: encrypted_author_name_data(post, current_user),
      user_avatar: author_avatar_fallback(post, current_user),
      encrypted_avatar_data: encrypted_author_avatar_data(post, current_user, key),
      author_profile_slug: author_profile_slug(post, current_user),
      author_profile_visibility: author_profile_visibility(post, current_user),
      bookmarked?: bookmarked?(post, current_user),
      unread?: unread?(post, current_user),
      peer_user_id: verification.peer_user_id,
      peer_public_key: verification.peer_public_key,
      peer_pq_public_key: verification.peer_pq_public_key,
      sealed_peer_pin: verification.sealed_peer_pin
    }
  end

  # --- client-side TOFU verified badge inputs (EPIC #291 / #296) -------------
  #
  # Resolves the post author's served public keys + the viewer's sealed key-pin
  # blob, so the browser `PeerVerifiedBadge` hook can MIRROR the out-of-band
  # verification state on the timeline card. Returns all-nil (no badge) for the
  # viewer's own posts and for authors who aren't connections (no pin can exist).
  # ZK-safe: the sealed pin is opaque to the server; the verdict is computed only
  # in the browser.
  defp verification(post, current_user) do
    empty = %{
      peer_user_id: nil,
      peer_public_key: nil,
      peer_pq_public_key: nil,
      sealed_peer_pin: nil
    }

    cond do
      post.user_id == current_user.id ->
        empty

      is_nil(Helpers.get_uconn_for_shared_item(post, current_user)) ->
        empty

      true ->
        case Accounts.get_user_with_preloads(post.user_id) do
          %Mosslet.Accounts.User{} = author ->
            %{
              peer_user_id: post.user_id,
              peer_public_key: get_in(author.key_pair, ["public"]),
              peer_pq_public_key: author.pq_public_key,
              sealed_peer_pin: Helpers.sealed_pin_for(current_user.id, post.user_id)
            }

          _ ->
            empty
        end
    end
  end

  # --- author display name ---------------------------------------------------
  #
  # Returns a display name for the post author in timeline cards.
  # For public posts, uses the already-decrypted username from post.decrypted
  # (populated by pre_decrypt_post via decrypt_post_fields).
  # For non-public posts, returns a placeholder — the browser-side DecryptPost
  # hook overwrites it via `data-decrypt-author-name-target`.
  defp author_name(post, current_user) do
    cond do
      post.user_id == current_user.id ->
        current_user.decrypted[:name] || current_user.decrypted[:username] || "..."

      post.decrypted[:username] ->
        post.decrypted[:username]

      true ->
        "..."
    end
  end

  # --- sealed author name payload (browser ZK) -------------------------------
  #
  # Returns encrypted author name data for browser-side ZK decryption.
  # For the current user's own posts, returns nil (pre_decrypt_user handles it).
  # For other users' posts, returns the sealed user_connection.key and encrypted
  # connection name/username blobs so the DecryptPost hook can decrypt them.
  defp encrypted_author_name_data(post, current_user) do
    cond do
      post.visibility == :public ->
        nil

      post.user_id == current_user.id ->
        nil

      true ->
        uconn = Helpers.get_uconn_for_shared_item(post, current_user)

        if uconn && uconn.connection && is_binary(uconn.key) do
          show_name? =
            uconn.connection.profile != nil and uconn.connection.profile.show_name?

          %{
            sealed_uconn_key: uconn.key,
            encrypted_name: if(show_name?, do: uconn.connection.name),
            encrypted_username: uconn.connection.username,
            show_name: show_name?
          }
        else
          # No personal UserConnection (e.g. a guardian viewing a managed
          # member's post). Fall back to the per-org `org_key` ZK resolution
          # (Task #225/#270): the viewer holds the family org_key and the author's
          # org display name is org_key-sealed, so the browser can resolve it.
          case Orgs.org_name_resolution_between_users(current_user.id, post.user_id) do
            %{sealed_org_key: sealed_org_key, encrypted_display_name: encrypted_display_name} ->
              %{
                sealed_org_key: sealed_org_key,
                encrypted_org_display_name: encrypted_display_name
              }

            _ ->
              nil
          end
        end
    end
  end

  # --- author avatar fallback ------------------------------------------------
  #
  # Fallback avatar URL for post cards when ZK data is nil (avatar hidden or
  # unavailable).
  defp author_avatar_fallback(post, current_user) do
    if post.user_id == current_user.id do
      if Helpers.show_avatar?(current_user),
        do: Helpers.mosslet_logo_for_theme(),
        else: "/images/logo.svg"
    else
      user_connection = Helpers.get_uconn_for_shared_item(post, current_user)

      if Helpers.show_avatar?(user_connection),
        do: Helpers.mosslet_logo_for_theme(),
        else: "/images/logo.svg"
    end
  end

  # --- sealed author avatar payload (browser ZK) -----------------------------
  #
  # Returns encrypted avatar data for browser-side ZK decryption on post cards.
  # For current user: uses conn_key sealed key.
  # For other users: uses UserConnection.key sealed key.
  # Returns nil when avatar is hidden or data unavailable (component falls back to logo).
  defp encrypted_author_avatar_data(post, current_user, key) do
    if post.user_id == current_user.id do
      if Helpers.show_avatar?(current_user),
        do: Helpers.get_encrypted_avatar_data(current_user, nil),
        else: nil
    else
      user_connection = Helpers.get_uconn_for_shared_item(post, current_user)

      cond do
        not is_nil(user_connection) ->
          if Helpers.show_avatar?(user_connection),
            do: Helpers.get_encrypted_avatar_data(user_connection, nil),
            else: nil

        true ->
          # Family guardian safety override (Task #284): no personal
          # UserConnection, but the viewer may be an ACTIVE guardian of the post
          # author. Surface the managed member's PERSONAL avatar so a minor can't
          # hide behind a misleading org avatar/initials. Server-authoritative —
          # gated by Orgs.guardian_avatar_key_for/2, intentionally bypassing the
          # managed member's display preferences for safety.
          guardian_post_author_avatar(post, current_user, key)
      end
    end
  end

  defp guardian_post_author_avatar(post, current_user, key) do
    case Orgs.guardian_avatar_key_for(current_user.id, post.user_id) do
      sealed_key when is_binary(sealed_key) ->
        case Accounts.get_user_with_preloads(post.user_id) do
          %Mosslet.Accounts.User{} = author ->
            Helpers.get_guardian_avatar_data(current_user, author, sealed_key, key)

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  # --- author profile link ---------------------------------------------------

  defp author_profile_slug(post, current_user) do
    cond do
      post.user_id == current_user.id ->
        case current_user.connection do
          %{profile: %{slug: slug}} when is_binary(slug) -> slug
          _ -> nil
        end

      true ->
        user_connection = Helpers.get_uconn_for_shared_item(post, current_user)

        if user_connection do
          case Accounts.get_user_with_preloads(post.user_id) do
            %{connection: %{profile: %{slug: slug}}} when is_binary(slug) -> slug
            _ -> nil
          end
        else
          nil
        end
    end
  end

  defp author_profile_visibility(post, current_user) do
    cond do
      post.user_id == current_user.id ->
        case current_user.connection do
          %{profile: %{visibility: visibility}} -> visibility
          _ -> nil
        end

      true ->
        user_connection = Helpers.get_uconn_for_shared_item(post, current_user)

        if user_connection do
          case Accounts.get_user_with_preloads(post.user_id) do
            %{connection: %{profile: %{visibility: visibility}}} -> visibility
            _ -> nil
          end
        else
          nil
        end
    end
  end

  # --- viewer-specific state -------------------------------------------------

  # Whether the post is bookmarked by the current user.
  defp bookmarked?(post, current_user) do
    case Timeline.bookmarked?(current_user, post) do
      result when is_boolean(result) -> result
      _ -> false
    end
  end

  # Whether the post is unread by the current user.
  defp unread?(post, current_user) do
    cond do
      Ecto.assoc_loaded?(post.user_post_receipts) ->
        case Enum.find(post.user_post_receipts || [], fn receipt ->
               receipt.user_id == current_user.id
             end) do
          # No receipt = treat as unread
          nil -> true
          # Use receipt status
          %{is_read?: is_read} -> !is_read
        end

      true ->
        # Fallback to database query if receipts not preloaded
        case Timeline.get_user_post_receipt(current_user, post) do
          # No receipt = unread
          nil -> true
          # Receipt exists and marked as read = read
          %{is_read?: true} -> false
          # Receipt exists but marked as unread = unread
          %{is_read?: false} -> true
          # Default to unread for any other case
          _ -> true
        end
    end
  end
end

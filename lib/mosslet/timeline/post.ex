defmodule Mosslet.Timeline.Post do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts
  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted
  alias Mosslet.Encrypted.Utils
  alias Mosslet.Groups
  alias Mosslet.Groups.{Group, UserGroup}
  alias Mosslet.Timeline.{Post, UserPost, Reply}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "posts" do
    field :avatar_url, Encrypted.Binary
    field :body, Encrypted.Binary
    field :username, Encrypted.Binary
    field :username_hash, Encrypted.HMAC
    field :image_urls, Encrypted.StringList, default: [], skip_default_validation: true
    field :image_urls_updated_at, :naive_datetime
    field :favs_list, Encrypted.StringList, default: [], skip_default_validation: true

    field :reposts_list, Encrypted.StringList,
      default: [],
      skip_default_validation: true

    field :favs_list_hash, Encrypted.HMAC
    field :reposts_list_hash, Encrypted.HMAC
    field :favs_count, :integer, default: 0
    field :reposts_count, :integer, default: 0
    field :repost, :boolean, default: false

    field :visibility, Ecto.Enum,
      values: [:public, :private, :connections, :specific_groups, :specific_users],
      default: :private

    # ENHANCED PRIVACY CONTROLS
    # Connection groups that can see this post
    field :visibility_groups, Encrypted.StringList, default: [], skip_default_validation: true
    field :visibility_groups_hash, Encrypted.HMAC
    # Specific users that can see this post
    field :visibility_users, Encrypted.StringList, default: [], skip_default_validation: true
    field :visibility_users_hash, Encrypted.HMAC
    # Whether replies are allowed
    field :allow_replies, :boolean, default: true
    # Whether sharing/reposts are allowed
    field :allow_shares, :boolean, default: true
    # Whether bookmarking is allowed
    field :allow_bookmarks, :boolean, default: true
    # Must be connection to reply
    field :require_follow_to_reply, :boolean, default: false
    # Mature content flag
    field :mature_content, :boolean, default: false
    # For temporary posts
    field :is_ephemeral, :boolean, default: false
    # When post gets auto-deleted
    field :expires_at, :naive_datetime
    # Virtual field for the UI dropdown selection
    field :expires_at_option, :string, virtual: true
    # Don't federate (future)
    field :local_only, :boolean, default: false

    # CONTENT WARNING FIELDS (encrypted with post_key for consistency)
    # Custom warning text (enacl encrypted with post_key, then Cloak at rest)
    field :content_warning, Encrypted.Binary
    # Category name (Cloak encrypted)
    field :content_warning_category, Encrypted.Binary
    # Searchable hash for filtering (hash of the category)
    field :content_warning_category_hash, Encrypted.HMAC
    # Quick filter flag
    field :content_warning?, :boolean, default: false

    field :user_post_map, :map, virtual: true

    embeds_many :shared_users, SharedUser, on_replace: :delete do
      @derive Jason.Encoder
      field :sender_id, :string, virtual: true
      field :username, :string, virtual: true
      field :user_id, :binary_id
      field :color, Ecto.Enum, values: [:emerald, :orange, :pink, :purple, :rose, :yellow, :zinc]
    end

    belongs_to :group, Group
    belongs_to :user_group, UserGroup
    belongs_to :original_post, Post
    belongs_to :user, User

    has_many :user_posts, UserPost
    has_many :user_post_receipts, through: [:user_posts, :user_post_receipt]
    has_many :replies, Reply, preload_order: [desc: :inserted_at]

    timestamps()
  end

  @doc false
  def changeset(post, attrs, opts \\ []) do
    post
    |> cast(attrs, [
      :avatar_url,
      :body,
      :username,
      :username_hash,
      :favs_count,
      :reposts_count,
      :reposts_list,
      :favs_list,
      :user_id,
      :visibility,
      :group_id,
      :user_group_id,
      :image_urls,
      :image_urls_updated_at,
      # Content warning fields
      :content_warning,
      :content_warning_category,
      :content_warning?,
      # NEW - Enhanced privacy control fields
      :visibility_groups,
      :visibility_users,
      :allow_replies,
      :allow_shares,
      :allow_bookmarks,
      :require_follow_to_reply,
      :mature_content,
      :is_ephemeral,
      :expires_at,
      # Virtual field for UI
      :expires_at_option,
      :local_only
    ])
    |> validate_required([:body, :username, :user_id])
    |> validate_length(:body, max: 500)
    |> add_username_hash()
    |> validate_visibility(opts)
    # NEW - Enhanced privacy validation
    |> validate_enhanced_privacy_controls(opts)
    |> validate_content_warning()
    # Convert virtual field to real datetime
    |> prepare_expires_at()
    |> encrypt_attrs(opts)
    |> cast_embed(:shared_users,
      with: &shared_user_changeset/2,
      sort_param: :shared_users_order,
      drop_param: :shared_users_delete
    )
  end

  @doc false
  def repost_changeset(post, attrs, opts \\ []) do
    post
    |> cast(attrs, [
      :avatar_url,
      :body,
      :username,
      :favs_list,
      :favs_count,
      :reposts_list,
      :reposts_count,
      :repost,
      :user_id,
      :original_post_id,
      :visibility,
      :group_id,
      :user_group_id,
      :image_urls,
      :image_urls_updated_at,
      :content_warning,
      :content_warning_category,
      :content_warning?,
      # NEW - Enhanced privacy control fields
      :visibility_groups,
      :visibility_users,
      :allow_replies,
      :allow_shares,
      :allow_bookmarks,
      :require_follow_to_reply,
      :mature_content
    ])
    |> validate_required([:body, :username, :reposts_list, :repost, :user_id, :original_post_id])
    |> add_username_hash()
    |> validate_content_warning()
    |> encrypt_attrs(opts)
    |> cast_embed(:shared_users,
      with: &shared_user_repost_changeset/2,
      sort_param: :shared_users_order,
      drop_param: :shared_users_delete
    )
  end

  def favs_changeset(post, attrs, opts \\ []) do
    post
    |> cast(attrs, [
      :favs_count,
      :favs_list
    ])
    |> validate_required([:favs_count, :favs_list])
    |> encrypt_favs_list_with_post_key(opts)
  end

  # Encrypt favs list with post_key (same pattern as post.body)
  defp encrypt_favs_list_with_post_key(changeset, opts) do
    if changeset.valid? && opts[:user] && opts[:key] do
      favs_list = get_field(changeset, :favs_list)

      if favs_list && length(favs_list) > 0 do
        # Get existing post_key for this post (not generate a new one)
        group_id = get_field(changeset, :group_id)
        visibility = get_field(changeset, :visibility)
        post_key = maybe_get_post_key(group_id, opts, visibility)

        # Asymmetrically encrypt each user_id individually with post_key
        # Follow same pattern as muted_users in UserTimelinePreference but with post_key
        encrypted_favs =
          Enum.map(favs_list, fn user_id ->
            # Each user_id encrypted individually with post_key
            # For posts, we need to use post_key instead of user_key like UserTimelinePreference
            Mosslet.Encrypted.Utils.encrypt(%{key: post_key, payload: user_id})
          end)

        # Create hash for searching
        favs_hash = Enum.join(favs_list, ",") |> String.downcase()

        changeset
        |> put_change(:favs_list_hash, favs_hash)
        # Also update the new encrypted field during transition
        |> put_change(:favs_list, encrypted_favs)
      else
        changeset
      end
    else
      changeset
    end
  end

  def shared_user_changeset(shared_user, attrs \\ %{}, _opts \\ []) do
    shared_user
    |> cast(attrs, [:sender_id, :username])
    |> validate_shared_username()
  end

  def shared_user_repost_changeset(shared_user, attrs \\ %{}, _opts \\ []) do
    shared_user
    |> cast(attrs, [:user_id])
  end

  def change_post_to_repost_changeset(post, attrs, opts \\ []) do
    post
    |> cast(attrs, [:reposts_list])
    |> encrypt_reposts_list_with_post_key(opts)
  end

  # Encrypt reposts list with post_key (same pattern as post.body)
  defp encrypt_reposts_list_with_post_key(changeset, opts) do
    if changeset.valid? && opts[:user] && opts[:key] do
      reposts_list = get_field(changeset, :reposts_list)

      if reposts_list && length(reposts_list) > 0 do
        # Get existing post_key for this post (not generate a new one)
        group_id = get_field(changeset, :group_id)
        visibility = get_field(changeset, :visibility)
        post_key = maybe_get_post_key(group_id, opts, visibility)

        # Asymmetrically encrypt each user_id individually with post_key
        # Same pattern as UserTimelinePreference but with post_key instead of user_key
        encrypted_reposts =
          Enum.map(reposts_list, fn user_id ->
            # Each user_id encrypted individually with post_key
            # For posts, we use post_key instead of user_key like UserTimelinePreference
            Mosslet.Encrypted.Utils.encrypt(%{key: post_key, payload: user_id})
          end)

        # Create hash for searching
        reposts_hash = Enum.join(reposts_list, ",") |> String.downcase()

        changeset
        |> put_change(:reposts_list_hash, reposts_hash)
        # Also update the new encrypted field during transition
        |> put_change(:reposts_list, encrypted_reposts)
      else
        changeset
      end
    else
      changeset
    end
  end

  def change_post_shared_users_changeset(post, attrs, _opts \\ []) do
    post
    |> cast(attrs, [])
    |> cast_embed(:shared_users,
      with: &shared_user_changeset/2,
      soft_param: :shared_users_order,
      drop_param: :shared_users_delete
    )
  end

  defp validate_shared_username(changeset) do
    changeset
    |> validate_required([:username])
    |> validate_length(:username, min: 2, max: 160)
    |> maybe_add_recipient_id_by_username()
  end

  # The recipient is either the user_id or reverse_user_id
  # of the connection.
  defp maybe_add_recipient_id_by_username(changeset) do
    username = get_change(changeset, :username, "")
    user_id = get_field(changeset, :sender_id)

    if recipient = Accounts.get_shared_user_by_username(user_id, username) do
      changeset
      |> put_change(:user_id, recipient.id)
    else
      changeset
      |> add_error(:username, "invalid or does not exist")
    end
  end

  defp add_username_hash(changeset) do
    if Map.has_key?(changeset.changes, :username) do
      changeset
      |> put_change(:username_hash, String.downcase(get_field(changeset, :username)))
    else
      changeset
    end
  end

  defp validate_visibility(changeset, opts) do
    visibility = get_field(changeset, :visibility)

    case visibility do
      :public ->
        changeset

      :private ->
        changeset

      :connections ->
        if Accounts.has_any_user_connections?(opts[:user]) do
          changeset
        else
          changeset |> add_error(:body, "Woopsy, first we need to make some connections.")
        end

      :specific_groups ->
        validate_specific_groups(changeset, opts)

      :specific_users ->
        validate_specific_users(changeset, opts)
    end
  end

  # NEW - Enhanced privacy validation
  defp validate_enhanced_privacy_controls(changeset, _opts) do
    changeset
    |> validate_expiration_date()
    |> validate_interaction_controls()
    |> validate_ephemeral_settings()
  end

  defp validate_specific_groups(changeset, opts) do
    visibility_groups = get_field(changeset, :visibility_groups)

    cond do
      !visibility_groups || Enum.empty?(visibility_groups) ->
        add_error(
          changeset,
          :visibility_groups,
          "must specify at least one group when using specific groups visibility"
        )

      !Accounts.has_any_user_connections?(opts[:user]) ->
        add_error(
          changeset,
          :visibility_groups,
          "you need connections before sharing with specific groups"
        )

      true ->
        changeset
    end
  end

  defp validate_specific_users(changeset, opts) do
    visibility_users = get_field(changeset, :visibility_users)

    cond do
      !visibility_users || Enum.empty?(visibility_users) ->
        add_error(
          changeset,
          :visibility_users,
          "must specify at least one user when using specific users visibility"
        )

      !Accounts.has_any_user_connections?(opts[:user]) ->
        add_error(
          changeset,
          :visibility_users,
          "you need connections before sharing with specific users"
        )

      true ->
        # Validate that specified users are actual connections
        validate_users_are_connections(changeset, opts)
    end
  end

  defp validate_users_are_connections(changeset, opts) do
    visibility_users = get_field(changeset, :visibility_users)

    user_connection_ids =
      Accounts.get_all_confirmed_user_connections(opts[:user])
      |> Enum.map(& &1.reverse_user_id)

    invalid_users = Enum.reject(visibility_users, &(&1 in user_connection_ids))

    if Enum.empty?(invalid_users) do
      changeset
    else
      add_error(changeset, :visibility_users, "can only share with your confirmed connections")
    end
  end

  defp validate_expiration_date(changeset) do
    expires_at = get_field(changeset, :expires_at)

    if expires_at do
      now = NaiveDateTime.utc_now()

      cond do
        NaiveDateTime.compare(expires_at, now) == :lt ->
          add_error(changeset, :expires_at, "expiration date must be in the future")

        NaiveDateTime.diff(expires_at, now, :day) > 365 ->
          add_error(
            changeset,
            :expires_at,
            "expiration date cannot be more than 1 year in the future"
          )

        true ->
          changeset
      end
    else
      changeset
    end
  end

  defp validate_interaction_controls(changeset) do
    # Note: We now allow ephemeral posts to be bookmarked
    # The bookmark will be automatically cleaned up when the post expires
    # This provides better UX and user agency
    changeset
  end

  defp validate_ephemeral_settings(changeset) do
    is_ephemeral = get_field(changeset, :is_ephemeral)
    expires_at = get_field(changeset, :expires_at)

    # Ephemeral posts should have expiration
    if is_ephemeral && !expires_at do
      # Auto-set expiration for ephemeral posts (24 hours) with truncated microseconds
      expires_at =
        NaiveDateTime.utc_now() |> NaiveDateTime.add(24, :hour) |> NaiveDateTime.truncate(:second)

      put_change(changeset, :expires_at, expires_at)
    else
      changeset
    end
  end

  # Content warning validation
  defp validate_content_warning(changeset) do
    content_warning_enabled? = get_field(changeset, :content_warning?)

    if content_warning_enabled? do
      changeset
      |> validate_required(:content_warning)
    else
      changeset
    end
  end

  # Convert expires_at_option (UI string) to expires_at (actual datetime)
  # This is the idiomatic Phoenix pattern for form field transformation
  # Truncate microseconds to avoid Ecto database errors
  defp prepare_expires_at(changeset) do
    case get_change(changeset, :expires_at_option) do
      nil ->
        changeset

      "" ->
        changeset

      "1_hour" ->
        expires_at =
          NaiveDateTime.utc_now()
          |> NaiveDateTime.add(1, :hour)
          |> NaiveDateTime.truncate(:second)

        put_change(changeset, :expires_at, expires_at)

      "6_hours" ->
        expires_at =
          NaiveDateTime.utc_now()
          |> NaiveDateTime.add(6, :hour)
          |> NaiveDateTime.truncate(:second)

        put_change(changeset, :expires_at, expires_at)

      "24_hours" ->
        expires_at =
          NaiveDateTime.utc_now()
          |> NaiveDateTime.add(24, :hour)
          |> NaiveDateTime.truncate(:second)

        put_change(changeset, :expires_at, expires_at)

      "7_days" ->
        expires_at =
          NaiveDateTime.utc_now() |> NaiveDateTime.add(7, :day) |> NaiveDateTime.truncate(:second)

        put_change(changeset, :expires_at, expires_at)

      "30_days" ->
        expires_at =
          NaiveDateTime.utc_now()
          |> NaiveDateTime.add(30, :day)
          |> NaiveDateTime.truncate(:second)

        put_change(changeset, :expires_at, expires_at)

      _other ->
        add_error(changeset, :expires_at_option, "invalid expiration option")
    end
  end

  defp encrypt_attrs(changeset, opts) do
    if changeset.valid? && opts[:user] && opts[:key] do
      body = get_field(changeset, :body)
      username = get_field(changeset, :username)
      visibility = get_field(changeset, :visibility)
      group_id = get_field(changeset, :group_id)
      post_key = maybe_generate_post_key(group_id, opts, visibility)

      e_avatar_url =
        if is_binary(post_key), do: maybe_encrypt_avatar_url(opts[:user], post_key)

      image_urls = get_field(changeset, :image_urls)

      e_image_urls =
        if image_urls && !Enum.empty?(image_urls) && post_key,
          do: encrypt_image_urls(image_urls, post_key)

      case visibility do
        :public ->
          changeset
          |> put_change(:avatar_url, e_avatar_url)
          |> put_change(:image_urls, e_image_urls)
          |> put_change(:body, Utils.encrypt(%{key: post_key, payload: body}))
          |> put_change(:username, Utils.encrypt(%{key: post_key, payload: username}))
          |> put_change(:user_post_map, %{temp_key: post_key})
          |> encrypt_favs_list(post_key, opts)
          |> encrypt_reposts_list(post_key, opts)
          |> encrypt_content_warning_if_present(post_key, opts)

        :private ->
          changeset
          |> put_change(:avatar_url, e_avatar_url)
          |> put_change(:image_urls, e_image_urls)
          |> put_change(:body, Utils.encrypt(%{key: post_key, payload: body}))
          |> put_change(:username, Utils.encrypt(%{key: post_key, payload: username}))
          |> put_change(:user_post_map, %{temp_key: post_key})
          |> encrypt_favs_list(post_key, opts)
          |> encrypt_reposts_list(post_key, opts)
          |> encrypt_content_warning_if_present(post_key, opts)

        :connections ->
          changeset
          |> put_change(:avatar_url, e_avatar_url)
          |> put_change(:image_urls, e_image_urls)
          |> put_change(:body, Utils.encrypt(%{key: post_key, payload: body}))
          |> put_change(:username, Utils.encrypt(%{key: post_key, payload: username}))
          |> put_change(:user_post_map, %{temp_key: post_key})
          |> encrypt_favs_list(post_key, opts)
          |> encrypt_reposts_list(post_key, opts)
          |> encrypt_content_warning_if_present(post_key, opts)

        _rest ->
          changeset |> add_error(:body, "There was an error determining the visibility.")
      end
    else
      changeset
    end
  end

  defp maybe_encrypt_avatar_url(user, post_key) do
    case user.avatar_url do
      nil ->
        nil

      avatar_url ->
        Utils.encrypt(%{key: post_key, payload: avatar_url})
    end
  end

  defp encrypt_image_urls(image_urls, post_key) do
    Enum.map(image_urls, fn image_url ->
      Utils.encrypt(%{key: post_key, payload: image_url})
    end)
  end

  # Encrypt and hash favs_list if present
  defp encrypt_favs_list(changeset, post_key, opts) do
    if changeset.valid? && opts[:user] && opts[:key] do
      favs_list = get_field(changeset, :favs_list)

      if favs_list && length(favs_list) > 0 do
        # Asymmetrically encrypt each user_id in the favs_list individually with post_key
        encrypted_favs_list =
          Enum.map(favs_list, fn favs_id ->
            Utils.encrypt(%{key: post_key, payload: favs_id})
          end)

        # Create hash for all user IDs (for search/cache invalidation)
        hash_value = Enum.join(favs_list, ",") |> String.downcase()

        changeset
        # StringList will symmetrically encrypt this list of asymmetrically encrypted values
        |> put_change(:favs_list, encrypted_favs_list)
        |> put_change(:favs_list_hash, hash_value)
      else
        changeset
      end
    else
      changeset
    end
  end

  # Encrypt and hash reposts_list if present
  defp encrypt_reposts_list(changeset, post_key, opts) do
    if changeset.valid? && opts[:user] && opts[:key] do
      reposts_list = get_field(changeset, :reposts_list)

      if reposts_list && length(reposts_list) > 0 do
        # Asymmetrically encrypt each user_id in the reposts_list individually with post_key
        encrypted_reposts_list =
          Enum.map(reposts_list, fn reposts_id ->
            Utils.encrypt(%{key: post_key, payload: reposts_id})
          end)

        # Create hash for all user IDs (for search/cache invalidation)
        hash_value = Enum.join(reposts_list, ",") |> String.downcase()

        changeset
        # StringList will symmetrically encrypt this list of asymmetrically encrypted values
        |> put_change(:reposts_list, encrypted_reposts_list)
        |> put_change(:reposts_list_hash, hash_value)
      else
        changeset
      end
    else
      changeset
    end
  end

  # Encrypt content warning text with the same post_key (for consistency)
  defp encrypt_content_warning_if_present(changeset, post_key, _opts) do
    content_warning = get_field(changeset, :content_warning)
    content_warning_category = get_field(changeset, :content_warning_category)

    changeset =
      if content_warning && String.trim(content_warning) != "" do
        encrypted_warning = Utils.encrypt(%{key: post_key, payload: content_warning})

        changeset
        |> put_change(:content_warning, encrypted_warning)
        |> put_change(:content_warning?, true)
      else
        changeset
        |> put_change(:content_warning?, false)
      end

    changeset =
      if content_warning_category && String.trim(content_warning_category) != "" do
        encrypted_category = Utils.encrypt(%{key: post_key, payload: content_warning_category})

        changeset
        |> put_change(:content_warning_category, encrypted_category)
        |> put_change(:content_warning_category_hash, String.downcase(content_warning_category))
      else
        changeset
      end

    changeset
  end

  # Get existing post key (for updates like favs/reposts)
  defp maybe_get_post_key(group_id, opts, visibility) do
    case visibility do
      :public ->
        Encrypted.Users.Utils.decrypt_public_item_key(opts[:post_key])

      _rest ->
        if not is_nil(group_id) do
          group = Groups.get_group!(group_id)
          user_group = Groups.get_user_group_for_group_and_user(group, opts[:user])

          {:ok, d_post_key} =
            Encrypted.Users.Utils.decrypt_user_attrs_key(
              user_group.key,
              opts[:user],
              opts[:key]
            )

          d_post_key
        else
          {:ok, d_post_key} =
            Encrypted.Users.Utils.decrypt_user_attrs_key(
              opts[:post_key],
              opts[:user],
              opts[:key]
            )

          d_post_key
        end
    end
  end

  defp maybe_generate_post_key(group_id, opts, visibility) do
    if opts[:update_post] do
      case visibility do
        :public ->
          Encrypted.Users.Utils.decrypt_public_item_key(opts[:trix_key])

        _rest ->
          if not is_nil(group_id) do
            group = Groups.get_group!(group_id)
            user_group = Groups.get_user_group_for_group_and_user(group, opts[:user])

            {:ok, d_post_key} =
              Encrypted.Users.Utils.decrypt_user_attrs_key(
                user_group.key,
                opts[:user],
                opts[:key]
              )

            d_post_key
          else
            {:ok, d_post_key} =
              Encrypted.Users.Utils.decrypt_user_attrs_key(
                opts[:post_key],
                opts[:user],
                opts[:key]
              )

            d_post_key
          end
      end
    else
      # creating a new post
      case visibility do
        # For public posts that are reposts, preserve the original public key
        :public ->
          if opts[:trix_key] do
            Encrypted.Users.Utils.decrypt_public_item_key(opts[:trix_key])
          else
            Encrypted.Utils.generate_key()
          end

        # use the group_key if associated with a group
        :connections ->
          if not is_nil(group_id) do
            group = Groups.get_group!(group_id)
            user_group = Groups.get_user_group_for_group_and_user(group, opts[:user])

            {:ok, d_post_key} =
              Encrypted.Users.Utils.decrypt_user_attrs_key(
                user_group.key,
                opts[:user],
                opts[:key]
              )

            d_post_key
          else
            if opts[:trix_key] do
              {:ok, d_post_key} =
                Encrypted.Users.Utils.decrypt_user_attrs_key(
                  opts[:trix_key],
                  opts[:user],
                  opts[:key]
                )

              d_post_key
            else
              Encrypted.Utils.generate_key()
            end
          end

        :private ->
          if opts[:trix_key] do
            {:ok, d_post_key} =
              Encrypted.Users.Utils.decrypt_user_attrs_key(
                opts[:trix_key],
                opts[:user],
                opts[:key]
              )

            d_post_key
          else
            Encrypted.Utils.generate_key()
          end

        _rest ->
          Encrypted.Utils.generate_key()
      end
    end
  end
end

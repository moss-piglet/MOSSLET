defmodule MossletWeb.Helpers do
  @moduledoc false
  use MossletWeb, :verified_routes

  require Logger

  use Gettext, backend: MossletWeb.Gettext

  alias Mosslet.Accounts
  alias Mosslet.Accounts.{User, UserConnection}
  alias Mosslet.Billing.{Plans, Subscriptions}
  alias Mosslet.Encrypted
  alias Mosslet.Extensions.{AvatarProcessor, MemoryProcessor}
  alias Mosslet.Groups
  alias Mosslet.Groups.{Group, UserGroup}
  alias Mosslet.Memories
  alias Mosslet.Memories.{Memory, Remark}
  alias Mosslet.Timeline
  alias Mosslet.Timeline.{Post, Reply}

  @folder "uploads/trix"
  # just less than 1 week (604,800)
  @url_expires_in 600_000

  ## AWS (s3)

  def url_expired?(post_updated_at) do
    duration = Timex.Duration.from_seconds(@url_expires_in)
    expiration_time = Timex.shift(post_updated_at, seconds: duration.seconds)
    offset_time = Timex.shift(expiration_time, seconds: -200)

    Timex.before?(offset_time, Timex.now())
  end

  @doc """
  The `src` is coming from our trix-content-hook and is the old
  presigned_url on the `a` and `img` html tags.
  """
  def get_file_key_with_ext(src) do
    src |> String.split("/") |> List.last() |> String.split("?") |> List.first()
  end

  @doc """
  The `src` is coming from our trix-content-hook and is the old
  presigned_url on the `a` and `img` html tags.
  """
  def get_ext_from_file_key(src) do
    src
    |> String.split(".")
    |> List.last()
    |> String.split("?")
    |> List.first()
  end

  @doc """
  Returns the file_path for an object in object storage where
  the ext is already included in the incoming string.
  """
  def get_file_path_for_s3(file_key_with_ext) do
    "#{@folder}/#{file_key_with_ext}"
  end

  @doc """
  Helper to generate a presigned_url for requests to object storage.
  Takes an optional config and options, otherwise we use the below
  config and options.

  This is slightly modified from the order of arguments accepted in our
  tigris.ex uploader file, as we do not need to modify the config when
  calling this function. Modifying the config should then mean we update
  our tigris.ex uploader as well.
  """
  def generate_presigned_url(request_type, object_key) do
    memories_bucket = Encrypted.Session.memories_bucket()
    region = Encrypted.Session.s3_region()
    s3_host = Encrypted.Session.s3_host()
    access_key_id = Encrypted.Session.s3_access_key_id()
    secret_key_access = Encrypted.Session.s3_secret_key_access()

    config = %{
      region: region,
      access_key_id: access_key_id,
      secret_access_key: secret_key_access
    }

    options = [
      virtual_host: true,
      bucket_as_host: true,
      expires_in: @url_expires_in
    ]

    # "https://#{memories_bucket}.#{s3_region}.#{s3_host}"
    # our s3_region is "auto" so we leave it out
    host_name = "https://#{memories_bucket}.#{s3_host}"

    case ExAws.S3.presigned_url(
           config,
           request_type,
           host_name,
           object_key,
           options
         ) do
      {:ok, presigned_url} ->
        {:ok, presigned_url}

      error ->
        error
    end
  end

  def get_s3_object(bucket, file_path) do
    ExAws.S3.get_object(bucket, file_path)
    |> ExAws.request()
  end

  @doc """
  This returns either the post_key for the current_user
  and the post, or generates and encrypts a new trix_key
  to be used as the post_key for encrypting Trix uploads.

  Replies to a Post use the already created post_key, so
  this is only ever used for a %Post{}.
  """
  def generate_and_encrypt_trix_key(current_user, post) do
    # checking the post.id handles when a new %Post{} is
    # in the socket.assigns (eg. new post form modal)
    if is_nil(post) || is_nil(post.id) do
      public_key = current_user.key_pair["public"]
      post_key = Encrypted.Utils.generate_key()

      Encrypted.Utils.encrypt_message_for_user_with_pk(post_key, %{
        public: public_key
      })
    else
      get_post_key(post, current_user)
    end
  end

  def decrypt_image_for_trix(e_obj, current_user, e_item_key, key, item, content_name, ext) do
    result = decr_item(e_obj, current_user, e_item_key, key, item, content_name)

    case result do
      :failed_verification ->
        Logger.info("Failed verification decrypting images from cloud in TimelineLive.Index")
        Logger.warning("failed_verification decrypting images (atom)")
        nil

      "failed_verification" ->
        Logger.info("Failed verification decrypting images from cloud in TimelineLive.Index")
        Logger.warning("failed_verification decrypting images (string)")
        nil

      "did not work" ->
        Logger.info("Did not work decrypting images from cloud in TimelineLive.Index")
        Logger.warning("did not work decrypting images")
        nil

      image when is_binary(image) ->
        build_image_from_binary_for_trix(image, ext)

      _ ->
        nil
    end
  end

  @doc """
  Decrypts the list of image urls associated with a (post). We
  currently call this when creating a repost.

  This returns the list of decrypted image urls or an empty list.
  """
  def decrypt_image_urls_for_repost(post, current_user, key) do
    post_key = get_post_key(post, current_user)
    image_urls = post.image_urls

    if is_list(image_urls) && !Enum.empty?(image_urls) do
      Enum.map(post.image_urls, fn e_image_url ->
        decr_item(e_image_url, current_user, post_key, key, post, "body")
      end)
    else
      []
    end
  end

  def build_image_from_binary_for_trix(image, ext) do
    case image do
      "failed_verification" ->
        nil

      binary when is_binary(binary) ->
        image = image |> Base.encode64()
        "data:image/#{ext};base64," <> image

      _ ->
        nil
    end
  end

  def decrypted_image_binaries_for_trix?(images) when is_list(images) do
    !Enum.empty?(images) &&
      Enum.all?(images, &(is_binary(&1) && String.starts_with?(&1, "data:image/")))
  end

  ## Customers

  def customer?(current_user) do
    Map.get(current_user.customer, :id)
  end

  ## Numbers

  def number_to_string(number) do
    case Mosslet.Cldr.Number.to_string(number) do
      {:ok, string} ->
        string

      _rest ->
        nil
    end
  end

  ## Conversations

  def assign_ai_tokens(user) do
    customer = Mosslet.Billing.Customers.get_customer_by_source(:user, user.id)

    subscription =
      Mosslet.Billing.Subscriptions.get_subscription_by(%{
        status: "active",
        billing_customer_id: customer.id
      }) ||
        Subscriptions.get_subscription_by(%{
          status: "trialing",
          billing_customer_id: customer.id
        })

    plan = Plans.get_plan_by_subscription!(subscription)

    case plan.name do
      "Starter" ->
        maybe_update_user_ai_tokens(user, 0)
        0

      "Lite" ->
        maybe_update_user_ai_tokens(user, 2_500)
        2_500

      "Plus" ->
        maybe_update_user_ai_tokens(user, 25_000)
        25_000

      "Pro" ->
        maybe_update_user_ai_tokens(user, 50_000)
        50_000

      "Pro AI" ->
        maybe_update_user_ai_tokens(user, 100_000)
        100_000

      _rest ->
        maybe_update_user_ai_tokens(user, 0)
        0
    end
  end

  def maybe_update_user_ai_tokens(user, tokens) do
    if user.ai_tokens == tokens do
      :ok
    else
      Accounts.update_user_tokens(user, %{ai_tokens: tokens})
    end
  end

  def total_ai_tokens(user) do
    user.ai_tokens
  end

  def total_ai_tokens_used(user) do
    user.ai_tokens_used
  end

  def monthly_tokens(ai_tokens, user) do
    case user.ai_tokens_used do
      nil ->
        ai_tokens - 0

      _rest ->
        Decimal.sub(ai_tokens, user.ai_tokens_used)
    end
  end

  ## Encryption

  def decr(_payload, _user, _key)

  def decr(payload, user, key) when is_binary(payload) do
    Encrypted.Users.Utils.decrypt_user_data(
      payload,
      user,
      key
    )
  end

  def decr(_payload, _user, _key), do: nil

  def decr_avatar(payload, user, item_key, key) do
    case Encrypted.Users.Utils.decrypt_user_item(
           payload,
           user,
           item_key,
           key
         ) do
      :failed_verification ->
        "failed_verification"

      payload ->
        payload
    end
  end

  # currently being used to handle stripe encryption changeover
  def maybe_decrypt_user_data(payload, user, key) do
    case Encrypted.Users.Utils.decrypt_user_data(payload, user, key) do
      :failed_verification ->
        # user data hasn't been asymetrically encrypted yet (due to legacy account)
        # so we return the payload as is
        payload

      decrypted_payload ->
        decrypted_payload
    end
  end

  def maybe_decr_username_for_user_group(user_id, current_user, key) do
    uconn = get_uconn_for_users!(user_id, current_user.id)

    cond do
      is_nil(uconn) && user_id != current_user.id ->
        "Private"

      is_nil(uconn) && user_id == current_user.id ->
        decr(current_user.username, current_user, key)

      true ->
        decr_uconn(uconn.connection.username, current_user, uconn.key, key)
    end
  end

  def decr_item(payload, user, item_key, key, item \\ nil, string_name \\ nil) do
    cond do
      group?(item) ->
        Encrypted.Users.Utils.decrypt_user_item(payload, user, item_key, key)

      remark?(item) ->
        Encrypted.Users.Utils.decrypt_user_item(payload, user, item_key, key)

      item && item.visibility == :public ->
        decr_public_item(payload, item_key)

      item && item.visibility == :private ->
        Encrypted.Users.Utils.decrypt_user_item(payload, user, item_key, key)

      item && item.visibility in [:connections, :specific_groups, :specific_users] &&
          item.user_id == user.id ->
        if string_name in ["body", "username", "name"] &&
             not is_nil(Map.get(item, :group_id, nil)) do
          group = Groups.get_group!(item.group_id)
          user_group = get_user_group(group, user)

          if not is_nil(user_group) do
            Encrypted.Users.Utils.decrypt_user_item(payload, user, user_group.key, key)
          else
            Encrypted.Users.Utils.decrypt_user_item(payload, user, item_key, key)
          end
        else
          case item do
            %Reply{} = reply = _item ->
              # check post_id first that way we don't always have to preload a post
              # this should always pass, phasing out group replies this way
              if reply.post_id || is_nil(reply.post.group_id) do
                Encrypted.Users.Utils.decrypt_item(payload, user, item_key, key)
              else
                group = Groups.get_group!(reply.post.group_id)
                user_group = get_user_group(group, user)

                {:ok, d_group_key} =
                  Encrypted.Users.Utils.decrypt_user_attrs_key(user_group.key, user, key)

                Encrypted.Users.Utils.decrypt_group_item(payload, d_group_key)
              end

            _rest ->
              Encrypted.Users.Utils.decrypt_item(payload, user, item_key, key)
          end
        end

      item && item.visibility in [:connections, :specific_groups, :specific_users] &&
          item.user_id != user.id ->
        if string_name in ["body", "username", "name"] &&
             not is_nil(Map.get(item, :group_id, nil)) do
          group = Groups.get_group!(item.group_id)
          user_group = get_user_group(group, user)

          if is_nil(user_group) do
            uconn = get_uconn_for_shared_item(item, user)
            maybe_decrypt_item_with_uconn(payload, uconn, item, user, key, item_key)
          else
            Encrypted.Users.Utils.decrypt_item(payload, user, user_group.key, key)
          end
        else
          case item do
            %Reply{} = reply = _item ->
              # check post_id first that way we don't always have to preload a post
              # this should always pass, phasing out group replies this way
              if reply.post_id || is_nil(reply.post.group_id) do
                Encrypted.Users.Utils.decrypt_item(payload, user, item_key, key)
              else
                group = Groups.get_group!(reply.post.group_id)
                user_group = get_user_group(group, user)

                {:ok, d_group_key} =
                  Encrypted.Users.Utils.decrypt_user_attrs_key(user_group.key, user, key)

                Encrypted.Users.Utils.decrypt_group_item(payload, d_group_key)
              end

            _rest ->
              Encrypted.Users.Utils.decrypt_item(payload, user, item_key, key)
          end
        end

      true ->
        "did not work"
    end
  end

  def decr_uconn_item(payload, user, uconn, key) do
    if is_nil(uconn) || is_nil(uconn.key) do
      # if the owner of the Memory is trying to decrypt their own data
      Encrypted.Users.Utils.decrypt_item(payload, user, user.conn_key, key)
    else
      # shared with people decrypting their connections data
      Encrypted.Users.Utils.decrypt_user_item(payload, user, uconn.key, key)
    end
  end

  def maybe_show_remark_username(data) do
    case data do
      :failed_verification ->
        "mystery"

      _rest ->
        data
    end
  end

  def maybe_show_remark_body(data) do
    case data do
      :failed_verification ->
        "mystery"

      _rest ->
        data
    end
  end

  defp maybe_decrypt_item_with_uconn(payload, uconn, item, user, key, item_key) do
    case uconn do
      nil ->
        if item do
          Encrypted.Users.Utils.decrypt_user_item(
            payload,
            user,
            get_username_remark_key(item, user),
            key
          )
        end

      _rest ->
        Encrypted.Users.Utils.decrypt_item(payload, user, item_key, key)
    end
  end

  def decr_public_item(payload, item_key) do
    Encrypted.Users.Utils.decrypt_public_item(payload, item_key)
  end

  def decr_uconn(payload, user, uconn_key, key) do
    Encrypted.Users.Utils.decrypt_user_item(
      payload,
      user,
      uconn_key,
      key
    )
  end

  def decr_group(payload, user, group_key, key) do
    Encrypted.Users.Utils.decrypt_user_item(
      payload,
      user,
      group_key,
      key
    )
  end

  def decr_attrs_key(payload_key, user, key) do
    {:ok, d_attrs_key} = Encrypted.Users.Utils.decrypt_user_attrs_key(payload_key, user, key)
    d_attrs_key
  end

  ## General (and mix of e1 repo functions)

  def main_menu_items(current_user) do
    MossletWeb.Menus.main_menu_items(current_user)
  end

  def user_menu_items(current_user) do
    MossletWeb.Menus.user_menu_items(current_user)
  end

  def public_menu_items(current_user) do
    MossletWeb.Menus.public_menu_items(current_user)
  end

  def public_menu_footer_items(current_user) do
    MossletWeb.Menus.public_menu_footer_items(current_user)
  end

  def get_menu_item(name, current_user) do
    MossletWeb.Menus.get_link(name, current_user)
  end

  # Always use this when rendering a user's name
  # This way, if you want to change to something like "user.first_name user.last_name", you only have to change one place
  def user_name(nil), do: nil
  def user_name(nil, nil), do: nil
  def user_name(nil, _key), do: nil
  def user_name(user, key), do: decr(user.name, user, key)

  def username(nil), do: nil
  def username(nil, nil), do: nil
  def username(nil, _key), do: nil
  def username(user, key), do: decr(user.username, user, key)

  # Use this for decryping a username
  def username(item, user, key) do
    cond do
      item.user_id == user.id ->
        # Current user's own item - use their username
        case decr(user.username, user, key) do
          username when is_binary(username) -> username
          # Graceful fallback for decryption issues
          :failed_verification -> "You"
          _ -> "You"
        end

      true ->
        case decr_item(item.username, user, get_item_key(item, user), key, item, "username") do
          username when is_binary(username) -> username
          :failed_verification -> "Private Author"
          _ -> "Private Author"
        end
    end
  end

  def user_avatar_url(nil), do: nil
  def user_avatar_url(_user), do: nil

  def home_path(nil), do: "/"
  def home_path(_current_user), do: ~p"/app"

  def admin?(%{is_admin: true}), do: true
  def admin?(_), do: false

  # Autofocuses the input
  # <input {alpine_autofocus()} />
  def alpine_autofocus do
    %{
      "x-data": "{}",
      "x-init": "$nextTick(() => { $el.focus() });"
    }
  end

  @doc """
  Display legacy Trix-Editor content formatted by Trix in the browser.
  """
  def html_block(content) when is_binary(content) do
    # Legacy posts with HTML - sanitize for security and render safely
    sanitized_html = HtmlSanitizeEx.html5(content)

    Phoenix.HTML.raw("""
    <div class="trix-content">
    #{sanitized_html}
    </div>
    """)
  end

  def html_block(nil), do: ""
  def html_block(""), do: ""

  # Fast HTML detection for legacy Trix posts
  def contains_html?(content) when is_binary(content) do
    # Quick check for common HTML patterns from legacy Trix editor
    String.contains?(content, [
      "<div",
      "<a",
      "<p>",
      "<br",
      "<strong",
      "<em>",
      "<ul>",
      "<li>",
      "<blockquote"
    ]) or
      String.match?(content, ~r/<[a-zA-Z!][^>]*>/)
  end

  def contains_html?(nil), do: false
  def contains_html?(""), do: false

  def initials(name) do
    case HumanName.initials(name) do
      {:ok, name} ->
        name

      {:error, error} ->
        cond do
          error == "No valid name found" ->
            name

          true ->
            error
        end
    end
  end

  def now() do
    Date.utc_today()
  end

  def can_edit?(user, item) when is_struct(item) do
    if user.id == item.user_id, do: true
  end

  def can_edit?(user, item) when is_map(item) do
    if user.id == item["user_id"], do: true
  end

  ## Groups

  def get_group(group_id) do
    Groups.get_group!(group_id)
  end

  # decrypts the current_user's user_connections
  # and builts a list for the live_search and group functionality.
  def decrypt_user_connections(user_connections, current_user, key) do
    uconns = Enum.with_index(user_connections)

    Enum.into(uconns, [], fn {uconn, _index} ->
      [
        key: decr_uconn(uconn.connection.username, current_user, uconn.key, key),
        value: uconn.connection.user_id,
        current_user_id: current_user.id
      ]
    end)
  end

  def decrypt_shared_user_connections(user_connections, current_user, key, atom \\ nil)

  def decrypt_shared_user_connections(user_connections, current_user, key, :post) do
    uconns = Enum.with_index(user_connections)

    Enum.into(uconns, [], fn {uconn, _index} ->
      %Post.SharedUser{
        sender_id: current_user.id,
        username: decr_uconn(uconn.connection.username, current_user, uconn.key, key),
        user_id: uconn.connection.user_id,
        color: uconn.color
      }
    end)
  end

  def decrypt_shared_user_connections(user_connections, current_user, key, :memory) do
    uconns = Enum.with_index(user_connections)

    Enum.into(uconns, [], fn {uconn, _index} ->
      %Memory.SharedUser{
        sender_id: current_user.id,
        username: decr_uconn(uconn.connection.username, current_user, uconn.key, key),
        user_id: uconn.connection.user_id,
        color: uconn.color
      }
    end)
  end

  def decrypt_shared_user_connections(_user_connections, _current_user, _key, nil), do: []

  # Fetches the UserGroup for the user and group.
  def get_user_group(group, user) do
    Groups.get_user_group_for_group_and_user(group, user)
  end

  # fetches the user from the user_group
  def get_user_from_user_group_id(user_group_id) when is_binary(user_group_id) do
    Groups.get_user_group_with_user!(user_group_id).user
  end

  def group?(%Group{} = _struct), do: true
  def group?(_struct), do: false

  def remark?(%Remark{} = _struct), do: true
  def remark?(_struct), do: false

  def user_group?(%UserGroup{} = _struct), do: true
  def user_group?(_struct), do: false

  @doc """
  Requires the `:user_groups` preloaded. Currently
  only allows the user who created a group to
  delete it.
  """
  def can_delete_group?(group, user) do
    cond do
      group.user_id == user.id ->
        true

      true ->
        false
    end
  end

  def can_join_group?(group, user_group, user) do
    cond do
      user_group.user_id == user.id &&
          user_group.id in Enum.into(group.user_groups, [], fn user_group -> user_group.id end) ->
        true

      true ->
        false
    end
  end

  def can_delete_user_group?(user_group, user) do
    cond do
      user_group.user_id == user.id ->
        true

      true ->
        false
    end
  end

  @doc """
  Takes a %UserGroup{} and %User{} and
  returns true if the user is an `:admin`
  or `:owner` role for the group.
  """
  @spec can_edit_group?(struct, struct) :: boolean
  def can_edit_group?(user_group, user) when is_struct(user_group) do
    cond do
      user_group.user_id == user.id && user_group.role in [:admin, :owner] ->
        true

      true ->
        false
    end
  end

  @spec can_edit_group?(any, any) :: boolean
  def can_edit_group?(_user_group, _user), do: false

  ## Posts (and Replies)

  def photos?(nil), do: false

  def photos?(image_urls) do
    Enum.empty?(image_urls) === false
  end

  def read?(user_post_receipt) do
    user_post_receipt && user_post_receipt.is_read?
  end

  def get_user_post_receipt(post, current_user) do
    if post.user_post_receipts do
      Enum.find(post.user_post_receipts, nil, fn user_post_receipt ->
        user_post_receipt.user_id === current_user.id
      end)
    end
  end

  def last_unread_post?(post, current_user) do
    unread_posts = Timeline.unread_posts(current_user)

    # Check if this post is the first (oldest) in the unread posts list
    case Enum.reverse(unread_posts) do
      [oldest_unread_post | _] -> oldest_unread_post.id == post.id
      _ -> false
    end
  end

  def get_user_from_post(post) do
    Accounts.get_user_from_post(post)
  end

  def get_user_from_item(item) do
    Accounts.get_user_from_item(item)
  end

  def can_fav?(user, item) do
    user.id not in item.favs_list
  end

  @doc """
  Returns the appropriate Mosslet logo based on current theme.
  Uses CSS media query to detect dark mode preference.
  """
  def mosslet_logo_for_theme() do
    # For now, we'll default to light version
    # In a real implementation, this could check user theme preference from the database
    # or use JavaScript to detect the current theme
    "/images/logo.svg"
  end

  @doc """
  Returns the dark theme Mosslet logo.
  """
  def mosslet_logo_dark() do
    "/images/logo_icon_dark.svg"
  end

  def can_repost?(user, post) do
    if post.user_id != user.id && user.id not in post.reposts_list do
      true
    else
      false
    end
  end

  # Enhanced Privacy Control Helper Functions
  # These functions check the new interaction controls we implemented

  @doc """
  Check if a user can reply to a post based on interaction controls.
  Considers allow_replies, require_follow_to_reply, and connection status.
  """
  def can_reply?(post, current_user) do
    cond do
      # If replies are disabled globally for this post
      !post.allow_replies ->
        false

      # If user is the post author, they can always reply to their own post
      post.user_id == current_user.id ->
        true

      # If post requires connection to reply (for public posts)
      post.require_follow_to_reply && post.visibility == :public ->
        user_has_connection_with_author?(current_user, post.user_id)

      # Otherwise, check general reply permissions
      true ->
        post.allow_replies
    end
  end

  @doc """
  Check if a user can bookmark a post based on interaction controls.
  """
  def can_bookmark?(post, current_user) do
    cond do
      # If bookmarking is disabled for this post
      !post.allow_bookmarks -> false
      # Users can always bookmark their own posts (for personal reference)
      post.user_id == current_user.id -> true
      # Otherwise, check if bookmarking is allowed
      true -> post.allow_bookmarks
    end
  end

  @doc """
  Check if a user has a confirmed connection with another user.
  Used for require_follow_to_reply functionality.
  """
  def user_has_connection_with_author?(current_user, author_user_id) do
    # Get all confirmed connections for the current user
    connections = Accounts.get_all_confirmed_user_connections(current_user.id)

    # Check if the author is in the user's connections
    Enum.any?(connections, fn conn ->
      conn.reverse_user_id == author_user_id || conn.user_id == author_user_id
    end)
  end

  @doc """
  Get privacy indicator color for timeline posts.
  Matches the color scheme used in privacy badges.
  """
  def get_privacy_indicator_color(post) do
    case post.visibility do
      :private -> "slate"
      :connections -> "emerald"
      :public -> "blue"
      :specific_groups -> "purple"
      :specific_users -> "amber"
      _ -> "slate"
    end
  end

  @doc """
  Get privacy indicator text for timeline posts.
  """
  def get_privacy_indicator_text(post) do
    case post.visibility do
      :private -> "Private"
      :connections -> "Connections"
      :public -> "Public"
      :specific_groups -> "Groups"
      :specific_users -> "Specific"
      _ -> "Private"
    end
  end

  @doc """
  Check if post will expire soon (within next 24 hours).
  Used for ephemeral post warnings.
  """
  def expires_soon?(post) do
    if post.is_ephemeral && post.expires_at do
      now = NaiveDateTime.utc_now()
      twenty_four_hours_from_now = NaiveDateTime.add(now, 24 * 60 * 60, :second)

      NaiveDateTime.compare(post.expires_at, twenty_four_hours_from_now) == :lt
    else
      false
    end
  end

  @doc """
  Get remaining time for ephemeral posts in human-readable format.
  """
  def get_expiration_time_remaining(post) do
    if post.is_ephemeral && post.expires_at do
      now = NaiveDateTime.utc_now()
      diff_seconds = NaiveDateTime.diff(post.expires_at, now, :second)

      cond do
        # Return nil for expired posts
        diff_seconds <= 0 -> nil
        diff_seconds < 60 -> "#{diff_seconds}s"
        diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m"
        diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h"
        true -> "#{div(diff_seconds, 86400)}d"
      end
    else
      nil
    end
  end

  def get_user!(id), do: Accounts.get_user!(id)
  def get_user_with_preloads(id), do: Accounts.get_user_with_preloads(id)

  def get_item_connection(%Memory{} = item, current_user) do
    cond do
      item.visibility == :public && not is_nil(current_user) ->
        Accounts.get_connection_from_item(item, current_user)

      item.visibility == :public && is_nil(current_user) ->
        "Sign in to view name"

      true ->
        Accounts.get_connection_from_item(item, current_user)
    end
  end

  def get_item_connection(item, current_user) do
    cond do
      item && item.visibility == :public && not is_nil(current_user) ->
        Accounts.get_connection_from_item(item, current_user)

      item && item.visibility == :public && is_nil(current_user) ->
        item

      true ->
        Accounts.get_connection_from_item(item, current_user)
    end
  end

  # only to be used if public memory
  def get_memory_key(memory) do
    Enum.at(memory.user_memories, 0).key
  end

  def get_memory_key(memory, current_user) do
    cond do
      memory.visibility == :connections || memory.visibility == :private ->
        user_memory = Memories.get_user_memory(memory, current_user)
        user_memory.key

      true ->
        Enum.at(memory.user_memories, 0).key
    end
  end

  def get_username_remark_key(remark, current_user) do
    memory = Memories.get_memory!(remark.memory_id)

    cond do
      remark.user_id != current_user.id ->
        uconn = get_uconn_for_shared_item(remark, current_user)
        maybe_get_uconn_key(uconn, memory)

      remark.user_id == current_user.id ->
        current_user.conn_key

      true ->
        Enum.at(memory.user_memories, 0).key
    end
  end

  def get_body_remark_key(remark, current_user) do
    memory = Memories.get_memory!(remark.memory_id)
    Memories.get_user_memory(memory, current_user).key
  end

  defp maybe_get_uconn_key(uconn, %Memory{} = item) do
    case uconn do
      nil ->
        Enum.at(item.user_memories, 0).key

      _rest ->
        uconn.key
    end
  end

  def get_post_key(post) do
    Enum.at(post.user_posts, 0).key
  end

  def get_post_key(post, current_user) do
    cond do
      post.group_id ->
        # there's only one UserPost for group posts
        case Enum.at(post.user_posts, 0) do
          %{key: key} -> key
          nil -> nil
        end

      post.visibility in [:connections, :private, :specific_groups, :specific_users] ->
        case Timeline.get_user_post(post, current_user) do
          %{key: key} -> key
          nil -> nil
        end

      true ->
        # there's only one UserPost for public posts
        case Enum.at(post.user_posts, 0) do
          %{key: key} -> key
          nil -> nil
        end
    end
  end

  # We can probably refactor to eventually only use this for all shared items
  def get_item_key(item, current_user) do
    cond do
      item.group_id ->
        # there's only one UserPost for group items
        case Enum.at(item.user_posts, 0) do
          %{key: key} -> key
          nil -> nil
        end

      item.visibility in [:connections, :specific_groups, :specific_users, :private] ->
        case Timeline.get_user_post(item, current_user) do
          %{key: key} -> key
          nil -> nil
        end

      true ->
        # there's only one UserPost for public posts
        case Enum.at(item.user_posts, 0) do
          %{key: key} -> key
          nil -> nil
        end
    end
  end

  def get_shared_item_identity_atom(item, user) do
    cond do
      item.visibility in [:connections, :specific_groups, :specific_users] &&
          item.user_id == user.id ->
        :self

      item.visibility in [:connections, :specific_groups, :specific_users] &&
        item.user_id != user.id &&
          user_in_item_connections(item, user) ->
        :connection

      item.visibility == :private && item.user_id == user.id ->
        :private

      item.visibility == :public && is_nil(user) ->
        :public

      item.visibility == :public && item.user_id != user.id ->
        :public

      item.visibility == :public && item.user_id == user.id ->
        :public_self

      true ->
        :invalid
    end
  end

  def get_shared_item_identity_atom(item, current_user, user) do
    cond do
      item.visibility in [:connections, :specific_groups, :specific_users] &&
          item.user_id == user.id ->
        :self

      item.visibility in [:connections, :specific_groups, :specific_users] &&
        item.user_id != user.id &&
          user_in_item_connections(item, user) ->
        :connection

      item.visibility == :private && item.user_id == user.id ->
        :private

      (item.visibility == :public && is_nil(current_user)) || item.user_id != current_user.id ->
        :public

      item.visibility == :public && not is_nil(current_user) && item.user_id == current_user.id ->
        :public_self

      true ->
        :invalid
    end
  end

  def get_shared_post_label(post, user, key) do
    case get_uconn_for_shared_item(post, user) do
      %UserConnection{} = uconn ->
        Encrypted.Users.Utils.decrypt_user_item(
          uconn.label,
          user,
          uconn.key,
          key
        )

      _rest ->
        "nil"
    end
  end

  def get_shared_memory_label(memory, user, key) do
    case get_uconn_for_shared_item(memory, user) do
      %UserConnection{} = uconn ->
        Encrypted.Users.Utils.decrypt_user_item(
          uconn.label,
          user,
          uconn.key,
          key
        )

      _rest ->
        "nil"
    end
  end

  def get_label_for_uconn(%UserConnection{} = uconn, user, key) do
    Encrypted.Users.Utils.decrypt_user_item(
      uconn.label,
      user,
      uconn.key,
      key
    )
  end

  def get_username_for_uconn(%UserConnection{} = uconn, user, key) do
    Encrypted.Users.Utils.decrypt_user_item(
      uconn.connection.username,
      user,
      uconn.key,
      key
    )
  end

  def get_username_for_uconn(_, _user, _key), do: nil

  def get_shared_item_user_connection(item, user) do
    Enum.map(item.shared_users, fn x ->
      u = Accounts.get_user(x.user_id)
      get_uconn_for_users(u, user)
    end)
  end

  def has_user_connection?(item, user) do
    unless is_nil(user) do
      case get_uconn_for_shared_item(item, user) do
        %UserConnection{} = _uconn ->
          true

        _rest ->
          false
      end
    end
  end

  def has_any_user_connections?(user) do
    Accounts.has_any_user_connections?(user)
  end

  def my_post?(post, user) do
    unless is_nil(user) do
      post.user_id == user.id
    end
  end

  def my_reply?(reply, user) do
    unless is_nil(user) do
      reply.user_id == user.id
    end
  end

  def get_uconn_color_for_shared_item(item, user) do
    cond do
      is_nil(user) ->
        :brand

      true ->
        case Accounts.get_user_connection_from_shared_item(item, user) do
          %UserConnection{} = uconn ->
            uconn.color

          nil ->
            nil
        end
    end
  end

  # If the user (current_user) is the same as the
  # item, then we return the user and not
  # the uconn.
  #
  # TODO: ???
  #
  # This function does not make sense to me. Need to
  # refactor and possibly remove.
  def get_uconn_for_shared_item(%User{} = item, user) do
    Accounts.get_user_connection_from_shared_item(item, user)
  end

  def get_uconn_for_shared_item(item, user) when is_struct(user) do
    if item.user_id == user.id do
      user
    else
      Accounts.get_user_connection_from_shared_item(item, user)
    end
  end

  # a non-signed in person is viewing a public item
  def get_uconn_for_shared_item(_item, user) when is_nil(user), do: nil

  defp user_in_item_connections(item, user) do
    uconns = Accounts.get_all_user_connections_from_shared_item(item, user)
    Enum.any?(uconns, fn uconn -> uconn.user_id == user.id end)
  end

  def users_shared_post?(post, user) do
    cond do
      post.visibility == :connections && post.user_id == user.id ->
        true

      true ->
        false
    end
  end

  ## UserConnections

  @doc """
  A helper banner to display whether someone has their
  visibility settings set to private. This way they can
  quickly realize why they can or cannot be found by
  friends.
  """
  def show_private_banner?(current_user) do
    current_user.visibility === :private
  end

  @doc """
  Returns true or false based on if a user_connection
  has a profile and has allowed their avatar to be shown.

  Note: we can also pass in the current_user struct in place
  of the user_connection as they match on the same connection struct.
  So we can use this for both connection avatars and personal avatars.
  """
  def show_avatar?(user_connection) do
    # Handle nil user_connection gracefully (for public posts from non-connections)
    case user_connection do
      nil ->
        false

      %{connection: nil} ->
        false

      %{connection: connection} ->
        profile = Map.get(connection, :profile, nil)
        if profile, do: profile.show_avatar?, else: false

      _ ->
        false
    end
  end

  def show_name?(user_connection) do
    # Handle nil user_connection gracefully (for public posts from non-connections)
    case user_connection do
      nil ->
        false

      %{connection: nil} ->
        false

      %{connection: connection} ->
        profile = Map.get(connection, :profile, nil)
        if profile, do: profile.show_name?, else: false

      _ ->
        false
    end
  end

  def show_email?(user_connection) do
    profile = Map.get(user_connection.connection, :profile, nil)

    if profile do
      profile.show_email?
    else
      false
    end
  end

  @doc """
  Returns the current_user's %UserConnection%{} that is
  connected to the `user_id`. The `user_id` is the
  `reverse_user_id` on the %UserConnection%{}.
  """
  def get_current_user_connection_between_users!(user_id, current_user_id) do
    Accounts.get_current_user_connection_between_users!(user_id, current_user_id)
  end

  ## TODO: phase out / replace / unclear
  # we are returning the user for the uconn if
  # the two user's are the same
  def get_uconn_for_users(user, current_user) do
    if user.id == current_user.id do
      user
    else
      Accounts.get_user_connection_between_users(user.id, current_user.id)
    end
  end

  # Muted user coming from the hydrated SharedUser mapping
  # used in our timeline_content_filter
  def get_uconn_for_muted_users(muted_user, current_user) do
    Accounts.get_user_connection_between_users(muted_user.user_id, current_user.id)
  end

  ## TODO: phase out / replace / unclear
  def get_uconn_for_users!(user_id, current_user_id) do
    Accounts.get_user_connection_between_users(user_id, current_user_id)
  end

  def get_uconn_key_for_users!(user_id, current_user_id) do
    uconn = Accounts.get_user_connection_between_users!(user_id, current_user_id)

    if not is_nil(uconn) do
      uconn.key
    else
      nil
    end
  end

  @doc """
  Checks if the user can download
  shared memories, based on the `UserConnection%{:photos?}`.

  The user_id is the current_user's id.
  """
  def check_if_user_can_download_shared_memory(memory_user_id, user_id) do
    uconns = Accounts.get_both_user_connections_between_users!(memory_user_id, user_id)
    # we are matching on the reverse_user_id in the user_connection
    # to determine if they can download the memory that's being shared
    Enum.find_value(uconns, fn uconn ->
      uconn.reverse_user_id == user_id && uconn.photos? == true
    end)
  end

  @doc """
  Checks if the Memory's user_id matches the user_id, enabling them
  to download their own memory.
  """
  def check_if_user_can_download_memory(memory_user_id, user_id) do
    memory_user_id == user_id
  end

  ## Profile

  # requires that the user
  # has a profile and the banner image
  # is our stored .jpg
  #
  def get_banner_image_for_user(user) do
    string = Atom.to_string(user.connection.profile.banner_image)
    "#{string}.jpg"
  end

  def get_banner_image_for_connection(connection) do
    if connection.profile do
      string = Atom.to_string(connection.profile.banner_image)
      "#{string}.jpg"
    else
      ""
    end
  end

  def get_banner_image(string) do
    if "" == string do
      "waves.jpg"
    else
      "#{string}.jpg"
    end
  end

  ## Avatars

  def get_user_avatar(user, key, item \\ nil, current_user \\ nil, item_list \\ [])

  def get_user_avatar(nil, _key, _item, _current_user, _item_list), do: nil

  def get_user_avatar(%User{} = user, key, nil, nil, []) do
    user = preload_connection(user)

    cond do
      is_nil(user.avatar_url) ->
        nil

      not is_nil(avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{user.connection.id}")) ->
        image =
          decr_avatar(
            avatar_binary,
            user,
            user.conn_key,
            key
          )
          |> Base.encode64()

        "data:image/jpg;base64," <> image

      is_nil(_avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{user.connection.id}")) ->
        avatars_bucket = Encrypted.Session.avatars_bucket()

        Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
          with {:ok, %{body: obj}} <-
                 ExAws.S3.get_object(
                   avatars_bucket,
                   decr_avatar(
                     user.connection.avatar_url,
                     user,
                     user.conn_key,
                     key
                   )
                 )
                 |> ExAws.request(),
               _decrypted_obj <-
                 decr_avatar(
                   obj,
                   user,
                   user.conn_key,
                   key
                 ) do
            # Only cache if avatar wasn't recently updated (prevents replica lag issues)
            unless AvatarProcessor.avatar_recently_updated?(user.connection.id) do
              AvatarProcessor.put_ets_avatar("profile-#{user.connection.id}", obj)
            end

            # We return this tuple to pattern match on our handle info and
            # pull the encrypted memory binary out of ets
            # This is used for the current_user's menus (eg. sidebar, settings)
            {"get_user_avatar", user.id}
          else
            {:error, _rest} ->
              "error"
          end
        end)
    end
  end

  def get_user_avatar(%User{} = user, key, item, current_user, item_list) do
    user = preload_connection(user)

    case item do
      %Memory{} = memory ->
        cond do
          is_nil(user.avatar_url) ->
            ""

          not is_nil(
            avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{user.connection.id}")
          ) ->
            image =
              decr_avatar(
                avatar_binary,
                user,
                user.conn_key,
                key
              )
              |> Base.encode64()

            "data:image/jpg;base64," <> image

          is_nil(_avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{user.connection.id}")) ->
            avatars_bucket = Encrypted.Session.avatars_bucket()

            Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
              with {:ok, %{body: obj}} <-
                     ExAws.S3.get_object(
                       avatars_bucket,
                       decr_avatar(
                         user.connection.avatar_url,
                         user,
                         user.conn_key,
                         key
                       )
                     )
                     |> ExAws.request(),
                   _decrypted_obj <-
                     decr_avatar(
                       obj,
                       user,
                       user.conn_key,
                       key
                     ) do
                # Only cache if avatar wasn't recently updated (prevents replica lag issues)
                unless AvatarProcessor.avatar_recently_updated?(user.connection.id) do
                  AvatarProcessor.put_ets_avatar("profile-#{user.connection.id}", obj)
                end

                # We return this tuple to pattern match on our handle info and
                # pull the encrypted avatar binary out of ets
                {"get_user_avatar", memory.id, item_list, current_user.id}
              else
                {:error, _rest} ->
                  "error"
              end
            end)
        end

      %Remark{} = remark ->
        cond do
          is_nil(user.avatar_url) ->
            ""

          not is_nil(
            avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{user.connection.id}")
          ) ->
            image =
              decr_avatar(
                avatar_binary,
                user,
                user.conn_key,
                key
              )
              |> Base.encode64()

            "data:image/jpg;base64," <> image

          is_nil(_avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{user.connection.id}")) ->
            avatars_bucket = Encrypted.Session.avatars_bucket()

            Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
              with {:ok, %{body: obj}} <-
                     ExAws.S3.get_object(
                       avatars_bucket,
                       decr_avatar(
                         user.connection.avatar_url,
                         user,
                         user.conn_key,
                         key
                       )
                     )
                     |> ExAws.request(),
                   _decrypted_obj <-
                     decr_avatar(
                       obj,
                       user,
                       user.conn_key,
                       key
                     ) do
                # Only cache if avatar wasn't recently updated (prevents replica lag issues)
                unless AvatarProcessor.avatar_recently_updated?(user.connection.id) do
                  AvatarProcessor.put_ets_avatar("profile-#{user.connection.id}", obj)
                end

                # We return this tuple to pattern match on our handle info and
                # pull the encrypted avatar binary out of ets
                {"get_user_avatar", remark.id, item_list, current_user.id}
              else
                {:error, _rest} ->
                  "error"
              end
            end)
        end

      %Reply{} = reply ->
        cond do
          is_nil(user.avatar_url) ->
            ""

          not is_nil(
            avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{user.connection.id}")
          ) ->
            image =
              decr_avatar(
                avatar_binary,
                user,
                user.conn_key,
                key
              )
              |> Base.encode64()

            "data:image/jpg;base64," <> image

          is_nil(_avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{user.connection.id}")) ->
            avatars_bucket = Encrypted.Session.avatars_bucket()

            Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
              with {:ok, %{body: obj}} <-
                     ExAws.S3.get_object(
                       avatars_bucket,
                       decr_avatar(
                         user.connection.avatar_url,
                         user,
                         user.conn_key,
                         key
                       )
                     )
                     |> ExAws.request(),
                   _decrypted_obj <-
                     decr_avatar(
                       obj,
                       user,
                       user.conn_key,
                       key
                     ) do
                # Only cache if avatar wasn't recently updated (prevents replica lag issues)
                unless AvatarProcessor.avatar_recently_updated?(user.connection.id) do
                  AvatarProcessor.put_ets_avatar("profile-#{user.connection.id}", obj)
                end

                # We return this tuple to pattern match on our handle info and
                # pull the encrypted avatar binary out of ets
                {"get_user_avatar_reply", reply.id, item_list, current_user.id}
              else
                {:error, _rest} ->
                  "error"
              end
            end)
        end

      %Post{} = post ->
        cond do
          is_nil(user.avatar_url) ->
            ""

          not is_nil(
            avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{user.connection.id}")
          ) ->
            image =
              decr_avatar(
                avatar_binary,
                user,
                user.conn_key,
                key
              )
              |> Base.encode64()

            "data:image/jpg;base64," <> image

          is_nil(_avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{user.connection.id}")) ->
            avatars_bucket = Encrypted.Session.avatars_bucket()

            Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
              with {:ok, %{body: obj}} <-
                     ExAws.S3.get_object(
                       avatars_bucket,
                       decr_avatar(
                         user.connection.avatar_url,
                         user,
                         user.conn_key,
                         key
                       )
                     )
                     |> ExAws.request(),
                   _decrypted_obj <-
                     decr_avatar(
                       obj,
                       user,
                       user.conn_key,
                       key
                     ) do
                # Only cache if avatar wasn't recently updated (prevents replica lag issues)
                unless AvatarProcessor.avatar_recently_updated?(user.connection.id) do
                  AvatarProcessor.put_ets_avatar("profile-#{user.connection.id}", obj)
                end

                # We return this tuple to pattern match on our handle info and
                # pull the encrypted avatar binary out of ets
                {"get_user_avatar", post.id, item_list, current_user.id}
              else
                {:error, _rest} ->
                  "error"
              end
            end)
        end
    end
  end

  def get_user_avatar(%UserConnection{} = uconn, key, item, current_user, item_list) do
    case item do
      nil ->
        # Handle decrypting the avatar for the user connection.
        cond do
          is_nil(uconn.connection.avatar_url) ->
            ""

          not is_nil(
            avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{uconn.connection.id}")
          ) ->
            image = decrypt_user_or_uconn_binary(avatar_binary, uconn, nil, key, nil)
            "data:image/jpg;base64," <> image

          is_nil(
            _avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{uconn.connection.id}")
          ) ->
            avatars_bucket = Encrypted.Session.avatars_bucket()

            Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
              with {:ok, %{body: obj}} <-
                     ExAws.S3.get_object(
                       avatars_bucket,
                       decr_avatar(
                         uconn.connection.avatar_url,
                         uconn.user,
                         uconn.key,
                         key
                       )
                     )
                     |> ExAws.request(),
                   _decrypted_obj <-
                     decr_avatar(
                       obj,
                       uconn.user,
                       uconn.key,
                       key
                     ) do
                # Only cache if avatar wasn't recently updated (prevents replica lag issues)
                unless AvatarProcessor.avatar_recently_updated?(uconn.connection.id) do
                  AvatarProcessor.put_ets_avatar("profile-#{uconn.connection.id}", obj)
                end

                # We return this tuple to pattern match on our handle info and
                # pull the encrypted memory binary out of ets
                # there is no item when decrypting a uconn for a user_connection
                # rather than, for example, a post or memory
                # so we return the uconn's id
                {"get_user_avatar", uconn.id, item_list, current_user.id}
              else
                {:error, _rest} ->
                  "error"
              end
            end)
        end

      %Memory{} = memory ->
        # we handle decrypting the avatar for the user connection and
        # possibly the current user if the memory is their own.
        cond do
          is_nil(uconn.connection.avatar_url) ->
            ""

          not is_nil(
            avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{uconn.connection.id}")
          ) ->
            image = decrypt_user_or_uconn_binary(avatar_binary, uconn, memory, key, current_user)
            "data:image/jpg;base64," <> image

          is_nil(
            _avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{uconn.connection.id}")
          ) &&
            not is_nil(current_user) && current_user != memory.user_id ->
            avatars_bucket = Encrypted.Session.avatars_bucket()

            Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
              with {:ok, %{body: obj}} <-
                     ExAws.S3.get_object(
                       avatars_bucket,
                       decr_avatar(
                         uconn.connection.avatar_url,
                         uconn.user,
                         uconn.key,
                         key
                       )
                     )
                     |> ExAws.request(),
                   _decrypted_obj <-
                     decr_avatar(
                       obj,
                       uconn.user,
                       uconn.key,
                       key
                     ) do
                # Only cache if avatar wasn't recently updated (prevents replica lag issues)
                unless AvatarProcessor.avatar_recently_updated?(uconn.connection.id) do
                  AvatarProcessor.put_ets_avatar("profile-#{uconn.connection.id}", obj)
                end

                # We return this tuple to pattern match on our handle info and
                # pull the encrypted memory binary out of ets
                {"get_user_avatar", memory.id, item_list, current_user.id}
              else
                {:error, _rest} ->
                  "error"
              end
            end)
        end

      %Post{} = post ->
        # we handle decrypting the avatar for the user connection and
        # possibly the current user if the post is their own.
        cond do
          is_nil(uconn.connection.avatar_url) ->
            ""

          not is_nil(
            avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{uconn.connection.id}")
          ) ->
            image = decrypt_user_or_uconn_binary(avatar_binary, uconn, post, key, current_user)
            "data:image/jpg;base64," <> image

          is_nil(
            _avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{uconn.connection.id}")
          ) &&
            not is_nil(current_user) && current_user != post.user_id ->
            avatars_bucket = Encrypted.Session.avatars_bucket()

            Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
              with {:ok, %{body: obj}} <-
                     ExAws.S3.get_object(
                       avatars_bucket,
                       decr_avatar(
                         uconn.connection.avatar_url,
                         uconn.user,
                         uconn.key,
                         key
                       )
                     )
                     |> ExAws.request(),
                   _decrypted_obj <-
                     decr_avatar(
                       obj,
                       uconn.user,
                       uconn.key,
                       key
                     ) do
                # Only cache if avatar wasn't recently updated (prevents replica lag issues)
                unless AvatarProcessor.avatar_recently_updated?(uconn.connection.id) do
                  AvatarProcessor.put_ets_avatar("profile-#{uconn.connection.id}", obj)
                end

                # We return this tuple to pattern match on our handle info and
                # pull the encrypted memory binary out of ets
                {"get_user_avatar", item.id, item_list, current_user.id}
              else
                {:error, _rest} ->
                  "error"
              end
            end)

          is_nil(
            _avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{uconn.connection.id}")
          ) &&
            not is_nil(current_user) && current_user.id == post.user_id ->
            avatars_bucket = Encrypted.Session.avatars_bucket()

            Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
              with {:ok, %{body: obj}} <-
                     ExAws.S3.get_object(
                       avatars_bucket,
                       decr_avatar(
                         uconn.connection.avatar_url,
                         current_user,
                         uconn.key,
                         key
                       )
                     )
                     |> ExAws.request(),
                   _decrypted_obj <-
                     decr_avatar(
                       obj,
                       current_user,
                       uconn.key,
                       key
                     ) do
                # Only cache if avatar wasn't recently updated (prevents replica lag issues)
                unless AvatarProcessor.avatar_recently_updated?(uconn.connection.id) do
                  AvatarProcessor.put_ets_avatar("profile-#{uconn.connection.id}", obj)
                end

                # We return this tuple to pattern match on our handle info and
                # pull the encrypted memory binary out of ets
                {"get_user_avatar", item.id, item_list, current_user.id}
              else
                {:error, _rest} ->
                  "error"
              end
            end)
        end

      %Reply{} = reply ->
        # we handle decrypting the avatar for the user connection and
        # possibly the current user if the reply is their own.
        cond do
          is_nil(uconn.connection.avatar_url) ->
            ""

          not is_nil(
            avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{uconn.connection.id}")
          ) ->
            image = decrypt_user_or_uconn_binary(avatar_binary, uconn, reply, key, current_user)
            "data:image/jpg;base64," <> image

          is_nil(
            _avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{uconn.connection.id}")
          ) &&
            not is_nil(current_user) && current_user != reply.user_id ->
            avatars_bucket = Encrypted.Session.avatars_bucket()

            Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
              with {:ok, %{body: obj}} <-
                     ExAws.S3.get_object(
                       avatars_bucket,
                       decr_avatar(
                         uconn.connection.avatar_url,
                         uconn.user,
                         uconn.key,
                         key
                       )
                     )
                     |> ExAws.request(),
                   _decrypted_obj <-
                     decr_avatar(
                       obj,
                       uconn.user,
                       uconn.key,
                       key
                     ) do
                # Only cache if avatar wasn't recently updated (prevents replica lag issues)
                unless AvatarProcessor.avatar_recently_updated?(uconn.connection.id) do
                  AvatarProcessor.put_ets_avatar("profile-#{uconn.connection.id}", obj)
                end

                # We return this tuple to pattern match on our handle info and
                # pull the encrypted memory binary out of ets
                {"get_user_avatar_reply", item.id, item_list, current_user.id}
              else
                {:error, _rest} ->
                  "error"
              end
            end)

          is_nil(
            _avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{uconn.connection.id}")
          ) &&
            not is_nil(current_user) && current_user.id == reply.user_id ->
            avatars_bucket = Encrypted.Session.avatars_bucket()

            Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
              with {:ok, %{body: obj}} <-
                     ExAws.S3.get_object(
                       avatars_bucket,
                       decr_avatar(
                         uconn.connection.avatar_url,
                         current_user,
                         uconn.key,
                         key
                       )
                     )
                     |> ExAws.request(),
                   _decrypted_obj <-
                     decr_avatar(
                       obj,
                       current_user,
                       uconn.key,
                       key
                     ) do
                # Only cache if avatar wasn't recently updated (prevents replica lag issues)
                unless AvatarProcessor.avatar_recently_updated?(uconn.connection.id) do
                  AvatarProcessor.put_ets_avatar("profile-#{uconn.connection.id}", obj)
                end

                # We return this tuple to pattern match on our handle info and
                # pull the encrypted memory binary out of ets
                {"get_user_avatar_reply", item.id, item_list, current_user.id}
              else
                {:error, _rest} ->
                  "error"
              end
            end)
        end

      %Remark{} = _remark ->
        # Handle decrypting the avatar for the user connection.
        cond do
          is_nil(uconn.connection.avatar_url) ->
            ""

          not is_nil(
            avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{uconn.connection.id}")
          ) ->
            image = decrypt_user_or_uconn_binary(avatar_binary, uconn, nil, key, nil)
            "data:image/jpg;base64," <> image

          is_nil(
            _avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{uconn.connection.id}")
          ) ->
            avatars_bucket = Encrypted.Session.avatars_bucket()

            Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
              with {:ok, %{body: obj}} <-
                     ExAws.S3.get_object(
                       avatars_bucket,
                       decr_avatar(
                         uconn.connection.avatar_url,
                         uconn.user,
                         uconn.key,
                         key
                       )
                     )
                     |> ExAws.request(),
                   _decrypted_obj <-
                     decr_avatar(
                       obj,
                       uconn.user,
                       uconn.key,
                       key
                     ) do
                # Only cache if avatar wasn't recently updated (prevents replica lag issues)
                unless AvatarProcessor.avatar_recently_updated?(uconn.connection.id) do
                  AvatarProcessor.put_ets_avatar("profile-#{uconn.connection.id}", obj)
                end

                # We return this tuple to pattern match on our handle info and
                # pull the encrypted memory binary out of ets
                {"get_user_avatar", item.id, item_list, current_user.id}
              else
                {:error, _rest} ->
                  "error"
              end
            end)
        end

      %UserGroup{} = _user_group ->
        # Handle decrypting the avatar for the user connection.
        cond do
          is_nil(uconn.connection.avatar_url) ->
            ""

          not is_nil(
            avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{uconn.connection.id}")
          ) ->
            image = decrypt_user_or_uconn_binary(avatar_binary, uconn, nil, key, nil)
            "data:image/jpg;base64," <> image

          is_nil(
            _avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{uconn.connection.id}")
          ) ->
            avatars_bucket = Encrypted.Session.avatars_bucket()

            Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
              with {:ok, %{body: obj}} <-
                     ExAws.S3.get_object(
                       avatars_bucket,
                       decr_avatar(
                         uconn.connection.avatar_url,
                         uconn.user,
                         uconn.key,
                         key
                       )
                     )
                     |> ExAws.request(),
                   _decrypted_obj <-
                     decr_avatar(
                       obj,
                       uconn.user,
                       uconn.key,
                       key
                     ) do
                # Only cache if avatar wasn't recently updated (prevents replica lag issues)
                unless AvatarProcessor.avatar_recently_updated?(uconn.connection.id) do
                  AvatarProcessor.put_ets_avatar("profile-#{uconn.connection.id}", obj)
                end

                # We return this tuple to pattern match on our handle info and
                # pull the encrypted memory binary out of ets
                {"get_user_avatar", item.id, item_list, current_user.id}
              else
                {:error, _rest} ->
                  "error"
              end
            end)
        end
    end
  end

  def get_public_user_avatar(user, profile, current_user) when is_map(profile) do
    cond do
      is_nil(profile.avatar_url) ->
        ""

      not is_nil(avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{user.connection.id}")) ->
        image = decr_public_item(avatar_binary, profile.profile_key)
        image = Base.encode64(image)
        "data:image/jpg;base64," <> image

      is_nil(_avatar_binary = AvatarProcessor.get_ets_avatar("profile-#{user.connection.id}")) ->
        avatars_bucket = Encrypted.Session.avatars_bucket()
        d_url = decr_public_item(profile.avatar_url, profile.profile_key)

        Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
          with {:ok, %{body: obj}} <-
                 ExAws.S3.get_object(
                   avatars_bucket,
                   d_url
                 )
                 |> ExAws.request(),
               _decrypted_obj <-
                 decr_public_item(
                   obj,
                   profile.profile_key
                 ) do
            # Only cache if avatar wasn't recently updated (prevents replica lag issues)
            unless AvatarProcessor.avatar_recently_updated?(user.connection.id) do
              AvatarProcessor.put_ets_avatar("profile-#{user.connection.id}", obj)
            end

            # We return this tuple to pattern match on our handle info and
            # pull the encrypted memory binary out of ets
            {"get_user_avatar", current_user.id}
          else
            {:error, _rest} ->
              ""
          end
        end)
    end
  end

  ## Memories

  def show_blur_memory?(memory, user) do
    cond do
      memory.blur && user.id == memory.user_id ->
        true

      Enum.any?(memory.shared_users, fn shared_user ->
        shared_user.blur && shared_user.user_id == user.id
      end) ->
        true

      true ->
        false
    end
  end

  def get_user_memory(user, key, memory \\ nil, current_user \\ nil, memory_list \\ [])

  def get_user_memory(nil, _key, _memory, _current_user, _memory_list), do: ""

  def get_user_memory(%User{} = user, key, memory, current_user, memory_list) do
    user = preload_connection(user)

    user_memory = Memories.get_user_memory(memory, user)

    cond do
      is_nil(memory.memory_url) ->
        ""

      not is_nil(
        memory_binary =
            MemoryProcessor.get_ets_memory(
              "user:#{user.id}-memory:#{memory.id}-key:#{user.connection.id}"
            )
      ) ->
        image =
          Encrypted.Users.Utils.decrypt_item(memory_binary, user, user_memory.key, key)
          |> Base.encode64()

        "data:image/jpg;base64," <> image

      is_nil(
        _memory_binary =
            MemoryProcessor.get_ets_memory(
              "user:#{user.id}-memory:#{memory.id}-key:#{user.connection.id}"
            )
      ) ->
        memories_bucket = Encrypted.Session.memories_bucket()

        Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
          with {:ok, %{body: obj}} <-
                 ExAws.S3.get_object(
                   memories_bucket,
                   decr_item(
                     memory.memory_url,
                     user,
                     user_memory.key,
                     key,
                     memory
                   )
                 )
                 |> ExAws.request(),
               _decrypted_obj <-
                 decr_item(
                   obj,
                   user,
                   user_memory.key,
                   key,
                   memory
                 ) do
            # Put the encrypted memory binary in ets.

            MemoryProcessor.put_ets_memory(
              "user:#{user.id}-memory:#{memory.id}-key:#{user.connection.id}",
              obj
            )

            # We return this tuple to pattern match on our handle info and
            # pull the encrypted memory binary out of ets
            {"get_user_memory", memory.id, memory_list, current_user.id}
          else
            {:error, _rest} ->
              "error"
          end
        end)
    end
  end

  def get_user_memory(%UserConnection{} = _uconn, key, memory, current_user, memory_list) do
    user_memory = Memories.get_user_memory(memory, current_user)

    case memory do
      nil ->
        ""

      %Memory{} = memory ->
        # we handle decrypting the memory for the user connection and
        # possibly the current user if the memory is their own.
        cond do
          not is_nil(
            memory_binary =
                MemoryProcessor.get_ets_memory(
                  "user:#{memory.user_id}-memory:#{memory.id}-key:#{user_memory.id}"
                )
          ) ->
            image = decrypt_memory_binary(memory_binary, user_memory, memory, key, current_user)
            "data:image/jpg;base64," <> image

          is_nil(
            _memory_binary =
                MemoryProcessor.get_ets_memory(
                  "user:#{memory.user_id}-memory:#{memory.id}-key:#{user_memory.id}"
                )
          ) &&
            not is_nil(current_user) && current_user != memory.user_id ->
            memories_bucket = Encrypted.Session.memories_bucket()

            Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
              with {:ok, %{body: obj}} <-
                     ExAws.S3.get_object(
                       memories_bucket,
                       decr_item(
                         memory.memory_url,
                         current_user,
                         user_memory.key,
                         key,
                         memory
                       )
                     )
                     |> ExAws.request(),
                   _decrypted_obj <-
                     decr_item(
                       obj,
                       current_user,
                       user_memory.key,
                       key,
                       memory
                     ) do
                # Put the encrypted memory binary in ets.
                MemoryProcessor.put_ets_memory(
                  "user:#{memory.user_id}-memory:#{memory.id}-key:#{user_memory.id}",
                  obj
                )

                # We return this tuple to pattern match on our handle info and
                # pull the encrypted memory binary out of ets
                {"get_user_memory", memory.id, memory_list, current_user.id}
              else
                {:error, _rest} ->
                  "error"
              end
            end)

          is_nil(
            _memory_binary =
                MemoryProcessor.get_ets_memory(
                  "user:#{memory.user_id}-memory:#{memory.id}-key:#{user_memory.id}"
                )
          ) &&
            not is_nil(current_user) && current_user.id == memory.user_id ->
            memories_bucket = Encrypted.Session.memories_bucket()

            Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
              with {:ok, %{body: obj}} <-
                     ExAws.S3.get_object(
                       memories_bucket,
                       decr_item(
                         memory.memory_url,
                         current_user,
                         user_memory.key,
                         key,
                         memory
                       )
                     )
                     |> ExAws.request(),
                   _decrypted_obj <-
                     decr_item(
                       obj,
                       current_user,
                       user_memory.key,
                       key,
                       memory
                     ) do
                # Put the encrypted memory binary in ets.

                MemoryProcessor.put_ets_memory(
                  "user:#{memory.user_id}-memory:#{memory.id}-key:#{user_memory.id}",
                  obj
                )

                # We return this tuple to pattern match on our handle info and
                # pull the encrypted memory binary out of ets
                {"get_user_memory", memory.id, memory_list, current_user.id}
              else
                {:error, _rest} ->
                  "error"
              end
            end)
        end
    end
  end

  def maybe_get_memory_src(memory, current_user, key, memory_list) do
    return =
      get_user_memory(
        get_uconn_for_shared_item(memory, current_user),
        key,
        memory,
        current_user,
        memory_list
      )

    case return do
      %Task{} = _return ->
        ""

      _rest ->
        return
    end
  end

  def maybe_get_public_memory_src(user, memory, _current_user, memory_list) do
    return =
      get_public_user_memory(
        user,
        memory,
        memory_list
      )

    case return do
      %Task{} = _return ->
        ""

      _rest ->
        return
    end
  end

  # Handle uconns differently.
  # we want the other user than the current user
  def maybe_get_avatar_src(%UserConnection{} = uconn, current_user, key, item_list) do
    user_id = if current_user.id == uconn.user_id, do: uconn.reverse_user_id, else: uconn.user_id
    user = Accounts.get_user_with_preloads(user_id)
    upd_uconn = Accounts.get_user_connection_between_users(user.id, current_user.id)

    return =
      get_user_avatar(
        upd_uconn,
        key,
        nil,
        current_user,
        item_list
      )

    case return do
      %Task{} = _return ->
        ""

      _rest ->
        return
    end
  end

  def maybe_get_avatar_src(item, current_user, key, item_list) do
    uconn = if item, do: get_uconn_for_shared_item(item, current_user)

    return =
      get_user_avatar(
        uconn,
        key,
        item,
        current_user,
        item_list
      )

    case return do
      %Task{} = _return ->
        ""

      _rest ->
        return
    end
  end

  # get the user's avatar when they're viz is public and it's their profile
  def maybe_get_public_profile_user_avatar(user, profile, current_user) do
    return = get_public_user_avatar(user, profile, current_user)

    case return do
      %Task{} = _return ->
        ""

      _rest ->
        return
    end
  end

  def maybe_get_user_avatar(current_user, key) do
    return =
      get_user_avatar(current_user, key)

    case return do
      %Task{} = _return ->
        ""

      _rest ->
        return
    end
  end

  def get_public_user_memory(user, memory, memory_list) do
    user_memory = Memories.get_public_user_memory(memory)

    cond do
      is_nil(memory) ->
        ""

      is_nil(memory.memory_url) ->
        ""

      not is_nil(
        memory_binary =
            MemoryProcessor.get_ets_memory(
              "profile-user:#{user.id}-memory:#{memory.id}-key:#{user_memory.id}"
            )
      ) ->
        image = decr_public_item(memory_binary, get_memory_key(memory)) |> Base.encode64()
        "data:image/jpg;base64," <> image

      is_nil(
        _memory_binary =
            MemoryProcessor.get_ets_memory(
              "profile-user:#{user.id}-memory:#{memory.id}-key:#{user_memory.id}"
            )
      ) ->
        memories_bucket = Encrypted.Session.memories_bucket()
        d_url = decr_public_item(memory.memory_url, get_memory_key(memory))

        Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
          with {:ok, %{body: obj}} <-
                 ExAws.S3.get_object(
                   memories_bucket,
                   d_url
                 )
                 |> ExAws.request(),
               _decrypted_obj <-
                 decr_public_item(
                   obj,
                   get_memory_key(memory)
                 ) do
            # Put the encrypted memory binary in ets.

            MemoryProcessor.put_ets_memory(
              "profile-user:#{user.id}-memory:#{memory.id}-key:#{user_memory.id}",
              obj
            )

            # We return this tuple to pattern match on our handle info and
            # pull the encrypted memory binary out of ets
            {"get_user_public_memory", memory.id, memory_list, user.id}
          else
            {:error, _rest} ->
              "error"
          end
        end)
    end
  end

  defp decrypt_memory_binary(memory_binary, user_memory, _memory, key, current_user) do
    Encrypted.Users.Utils.decrypt_item(
      memory_binary,
      current_user,
      user_memory.key,
      key
    )
    |> Base.encode64()
  end

  defp decrypt_user_or_uconn_binary(avatar_binary, uconn, post, key, current_user) do
    cond do
      is_nil(current_user) ->
        decr_avatar(
          avatar_binary,
          uconn.user,
          uconn.key,
          key
        )
        |> Base.encode64()

      not is_nil(current_user) && post.user_id != current_user.id ->
        decr_avatar(
          avatar_binary,
          uconn.user,
          uconn.key,
          key
        )
        |> Base.encode64()

      not is_nil(current_user) && post.user_id == current_user.id ->
        decr_avatar(
          avatar_binary,
          current_user,
          current_user.conn_key,
          key
        )
        |> Base.encode64()
    end
  end

  defp preload_connection(user) do
    Accounts.preload_connection(user)
  end

  ## Errors

  def error_to_string(:too_large),
    do:
      Gettext.gettext(
        MossletWeb.Gettext,
        "Gulp! File too large (max #{Sizeable.filesize(10_000_000)})."
      )

  def error_to_string(:too_many_files),
    do: gettext("Whoa, too many files.")

  def error_to_string(:not_accepted),
    do: gettext("Sorry, that's not an acceptable file type.")

  def error_to_string(error), do: error

  ## CSS styling

  def border_color(color) do
    case color do
      :brand -> "border-emerald-700 dark:border-emerald-300 hover:border-emerald-500"
      :emerald -> "border-emerald-700 dark:border-emerald-300 hover:border-emerald-500"
      :orange -> "border-orange-700 dark:border-orange-300 hover:border-orange-500"
      :pink -> "border-pink-700 dark:border-pink-300 hover:border-pink-500"
      :purple -> "border-purple-700 dark:border-purple-300 hover:border-purple-500"
      :rose -> "border-rose-700 dark:border-rose-700 hover:border-rose-500"
      :yellow -> "border-yellow-700 dark:border-yellow-300 hover:border-yellow-500"
      :zinc -> "border-zinc-700 dark:border-gray-300 hover:border-zinc-500"
      _rest -> "border-emerald-700 dark:border-emerald-300 hover:border-emerald-500"
    end
  end

  def username_link_text_color(color) do
    case color do
      :brand -> "text-emerald-700 dark:text-emerald-300 hover:text-emerald-500"
      :emerald -> "text-emerald-700 dark:text-emerald-300 hover:text-emerald-500"
      :orange -> "text-orange-700 dark:text-orange-300 hover:text-orange-500"
      :pink -> "text-pink-700 dark:text-pink-300 hover:text-pink-500"
      :purple -> "text-purple-700 dark:text-purple-300 hover:text-purple-500"
      :rose -> "text-rose-700 dark:text-rose-700 hover:text-rose-500"
      :yellow -> "text-yellow-700 dark:text-yellow-300 hover:text-yellow-500"
      :zinc -> "text-zinc-700 dark:text-gray-300 hover:text-zinc-500"
      _rest -> "text-emerald-700 dark:text-emerald-300 hover:text-emerald-500"
    end
  end

  def username_link_text_color_group(color) do
    case color do
      :brand -> "text-emerald-700 dark:text-emerald-300 group-hover:text-emerald-500"
      :emerald -> "text-emerald-700 dark:text-emerald-300 group-hover:text-emerald-500"
      :orange -> "text-orange-700 dark:text-orange-300 group-hover:text-orange-500"
      :pink -> "text-pink-700 dark:text-pink-300 group-hover:text-pink-500"
      :purple -> "text-purple-700 dark:text-purple-300 group-hover:text-purple-500"
      :rose -> "text-rose-700 dark:text-rose-700 group-hover:text-rose-500"
      :yellow -> "text-yellow-700 dark:text-yellow-300 group-hover:text-yellow-500"
      :zinc -> "text-zinc-700 dark:text-gray-300 group-hover:text-zinc-500"
      _rest -> "text-emerald-700 dark:text-emerald-300 group-hover:text-emerald-500"
    end
  end

  def username_link_text_color_no_hover(color) do
    case color do
      :brand -> "text-emerald-700 dark:text-emerald-300"
      :emerald -> "text-emerald-700 dark:text-emerald-300"
      :orange -> "text-orange-700 dark:text-orange-300"
      :pink -> "text-pink-700 dark:text-pink-300"
      :purple -> "text-purple-700 dark:text-purple-300"
      :rose -> "text-rose-700 dark:text-rose-700"
      :yellow -> "text-yellow-700 dark:text-yellow-300"
      :zinc -> "text-zinc-700 dark:text-gray-300"
      _rest -> "text-emerald-700 dark:text-emerald-300"
    end
  end

  def badge_color(color) do
    case color do
      :brand ->
        "bg-emerald-50 dark:bg-emerald-900 text-emerald-700 dark:text-emerald-300 ring-emerald-600/20"

      :emerald ->
        "bg-emerald-50 dark:bg-emerald-950 text-emerald-700 dark:text-emerald-300 ring-emerald-600/20"

      :orange ->
        "bg-orange-50 dark:bg-orange-950 text-orange-700 dark:text-orange-300 ring-orange-600/20"

      :pink ->
        "bg-pink-50 dark:bg-pink-950 text-pink-700 dark:text-pink-300 ring-pink-600/20"

      :purple ->
        "bg-purple-50 dark:bg-purple-950 text-purple-700 dark:text-purple-300 ring-purple-600/20"

      :rose ->
        "bg-rose-50 dark:bg-rose-950 text-rose-700 dark:text-rose-700 ring-rose-600/20"

      :yellow ->
        "bg-yellow-50 dark:bg-yellow-950 text-yellow-700 dark:text-yellow-300 ring-yellow-600/20"

      :zinc ->
        "bg-zinc-50 dark:bg-gray-950 text-zinc-700 dark:text-gray-300 ring-zinc-600/20"

      _rest ->
        "bg-emerald-50 dark:bg-emerald-950 text-emerald-700 dark:text-emerald-300 ring-emerald-600/20"
    end
  end

  def role_badge_color(role) do
    case role do
      :owner ->
        "inline-flex items-center rounded-md bg-emerald-100 px-2 py-1 text-xs font-medium text-emerald-700 dark:text-emerald-300"

      :member ->
        "inline-flex items-center rounded-md bg-cyan-100 px-2 py-1 text-xs font-medium text-cyan-700 dark:bg-cyan-800 dark:text-cyan-300"

      :admin ->
        "inline-flex items-center rounded-md bg-orange-100 px-2 py-1 text-xs font-medium text-orange-700 dark:text-orange-300"

      :moderator ->
        "inline-flex items-center rounded-md bg-purple-100 px-2 py-1 text-xs font-medium text-purple-700 dark:text-purple-300"

      _rest ->
        "inline-flex items-center rounded-md bg-cyan-100 px-2 py-1 text-xs font-medium text-cyan-700"
    end
  end

  def role_badge_color_ring(role) do
    case role do
      :owner ->
        "rounded-md bg-emerald-50 dark:bg-emerald-900 px-2 py-1 text-xs font-medium text-emerald-600 dark:text-emerald-400 ring-1 ring-inset ring-emerald-600/20"

      :member ->
        "rounded-md bg-cyan-50 dark:bg-cyan-900 px-2 py-1 text-xs font-medium text-cyan-600 dark:text-cyan-400 ring-1 ring-inset ring-cyan-600/20"

      :admin ->
        "rounded-md bg-orange-50 px-2 py-1 text-xs font-medium text-orange-600 ring-1 ring-inset ring-orange-600/20"

      :moderator ->
        "rounded-md bg-purple-50 px-2 py-1 text-xs font-medium text-purple-600 ring-1 ring-inset ring-purple-600/20"

      _rest ->
        "rounded-md bg-cyan-50 px-2 py-1 text-xs font-medium text-cyan-600 ring-1 ring-inset ring-cyan-600/20"
    end
  end

  @doc """
  Used to style the avatar in the list of groups
  on the index page of Group Live, using the .group_avatar function.
  """
  def group_avatar_role_style(role) do
    case role do
      :owner ->
        "relative z-30 inline-block h-8 w-8 rounded-full ring-2 ring-emerald-600 dark:ring-emerald-400 bg-white dark:bg-gray-950"

      :member ->
        "relative z-30 inline-block h-8 w-8 rounded-full ring-2 ring-cyan-600 dark:ring-cyan-400 bg-white dark:bg-gray-950"

      :admin ->
        "relative z-30 inline-block h-8 w-8 rounded-full ring-2 ring-orange-600 dark:ring-orange-400 bg-white dark:bg-gray-950"

      :moderator ->
        "relative z-30 inline-block h-8 w-8 rounded-full ring-2 ring-purple-600 dark:ring-purple-400 bg-white dark:bg-gray-950"

      _rest ->
        "relative z-30 inline-block h-8 w-8 rounded-full ring-2 ring-cyan-600 dark:ring-cyan-400 bg-white dark:bg-gray-950"
    end
  end

  @doc """
  Used to style the fingerprint in the list of groups
  on the index page of Group Live.
  """
  def group_fingerprint_role_style(role) do
    case role do
      :owner ->
        "text-emerald-600 dark:text-emerald-400 text-xs"

      :member ->
        "text-cyan-600 dark:text-cyan-400 text-xs"

      :admin ->
        "text-orange-600 dark:text-orange-400 text-xs"

      :moderator ->
        "text-purple-600 dark:text-purple-400 text-xs"

      _rest ->
        "text-cyan-600 dark:text-cyan-400 text-xs"
    end
  end

  def badge_group_hover_color(color) do
    case color do
      :brand -> "group-hover:text-emerald-700 dark:group-hover:text-emerald-300"
      :emerald -> "group-hover:text-emerald-700 dark:group-hover:text-emerald-300"
      :orange -> "group-hover:text-orange-700 dark:group-hover:text-orange-300"
      :pink -> "group-hover:text-pink-700 dark:group-hover:text-pink-300"
      :purple -> "group-hover:text-purple-700 dark:group-hover:text-purple-300"
      :rose -> "group-hover:text-rose-700 dark:group-hover:text-rose-700"
      :yellow -> "group-hover:text-yellow-700 dark:group-hover:text-yellow-300"
      :zinc -> "group-hover:text-zinc-700 dark:group-hover:text-gray-300"
      _rest -> "group-hover:text-emerald-700 dark:group-hover:text-emerald-300"
    end
  end

  def badge_svg_fill_color(color) do
    case color do
      :brand -> "fill-brand-500"
      :emerald -> "fill-emerald-500"
      :orange -> "fill-orange-500"
      :pink -> "fill-pink-500"
      :purple -> "fill-purple-500"
      :rose -> "fill-rose-500"
      :yellow -> "fill-yellow-500"
      :zinc -> "fill-zinc-500"
      _rest -> "fill-brand-500"
    end
  end

  # Timeline Post Status Helper Functions

  @doc """
  Get visual indicator classes for post privacy level.
  Returns classes for the privacy badge.
  """
  def get_privacy_badge_classes(post) do
    base_classes = "inline-flex items-center px-2 py-1 rounded-full text-xs font-medium"

    color_classes =
      case post.visibility do
        :private ->
          "bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-300"

        :connections ->
          "bg-emerald-100 text-emerald-700 dark:bg-emerald-900 dark:text-emerald-300"

        :public ->
          "bg-blue-100 text-blue-700 dark:bg-blue-900 dark:text-blue-300"

        :specific_groups ->
          "bg-purple-100 text-purple-700 dark:bg-purple-900 dark:text-purple-300"

        :specific_users ->
          "bg-amber-100 text-amber-700 dark:bg-amber-900 dark:text-amber-300"

        _ ->
          "bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-300"
      end

    "#{base_classes} #{color_classes}"
  end
end

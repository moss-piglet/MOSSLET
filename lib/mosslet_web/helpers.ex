defmodule MossletWeb.Helpers do
  @moduledoc false
  use MossletWeb, :verified_routes

  use Gettext, backend: MossletWeb.Gettext

  alias Mosslet.Accounts
  alias Mosslet.Accounts.{User, UserConnection}
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Encrypted
  alias Mosslet.Extensions.AvatarProcessor
  alias Mosslet.Extensions.BannerProcessor
  alias Mosslet.Groups
  alias Mosslet.Groups.{Group, UserGroup}
  alias Mosslet.Memories
  alias Mosslet.Memories.{Memory, Remark}
  alias Mosslet.Timeline
  alias Mosslet.Timeline.{Post, Reply}

  @folder "uploads/trix"
  @url_expires_in 600_000

  ## AWS (s3)

  def url_expired?(updated_at) do
    expiration_time = DateTime.add(updated_at, @url_expires_in, :second)
    offset_time = DateTime.add(expiration_time, -200, :second)

    DateTime.before?(offset_time, DateTime.utc_now())
  end

  @doc """
  The `src` is coming from our trix-content-hook and is the old
  presigned_url on the `a` and `img` html tags. We force the .webp
  extension since all uploads are now stored as webp files.
  """
  def get_file_key_with_ext(src) do
    file_key_with_ext =
      src |> String.split("/") |> List.last() |> String.split("?") |> List.first()

    file_key = file_key_with_ext |> String.split(".") |> List.first()
    "#{file_key}.webp"
  end

  @doc """
  Returns the file extension for a given file key.
  All uploads are stored as webp files.
  """
  def get_ext_from_file_key(_src), do: "webp"

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
  def generate_and_encrypt_trix_key(current_user, post, visibility \\ nil) do
    if is_nil(post) || is_nil(post.id) do
      post_key = Encrypted.Utils.generate_key()

      if visibility in [:public, "public"] do
        Encrypted.Utils.encrypt_message_for_user_with_pk(post_key, %{
          public: Encrypted.Session.server_public_key()
        })
      else
        public_key = current_user.key_pair["public"]

        Encrypted.Utils.encrypt_message_for_user_with_pk(
          post_key,
          %{public: public_key},
          Encrypted.Utils.pq_opts_for_user(current_user)
        )
      end
    else
      get_post_key(post, current_user)
    end
  end

  def decrypt_image_for_trix(e_obj, current_user, e_item_key, key, item, content_name, ext) do
    result = decr_item(e_obj, current_user, e_item_key, key, item, content_name)

    case result do
      :failed_verification ->
        nil

      "failed_verification" ->
        nil

      "did not work" ->
        nil

      image when is_binary(image) ->
        build_image_from_binary_for_trix(image, ext)

      _ ->
        nil
    end
  end

  @doc """
  Get the extension for a content type.
  """
  def ext(content_type) do
    [ext | _] = MIME.extensions(content_type)

    case ext do
      "jpg" -> "webp"
      "jpeg" -> "webp"
      "png" -> "webp"
      _rest -> "webp"
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

  @doc """
  Check if a user has already paid for the service.
  Returns true if they have either:
  1. An active payment intent
  2. An active legacy subscription
  """
  def user_has_paid?(current_user) do
    alias Mosslet.Billing.{Customers, PaymentIntents, Subscriptions}

    case Customers.get_customer_by_source(:user, current_user.id) do
      %Customers.Customer{} = customer ->
        # Check for active payment intent first (new one-time payment system)
        case PaymentIntents.get_active_payment_intent_by_customer_id(customer.id) do
          %PaymentIntents.PaymentIntent{} ->
            true

          _ ->
            # Check for legacy subscription
            case Subscriptions.get_active_subscription_by_customer_id(customer.id) do
              %Subscriptions.Subscription{} -> true
              _ -> false
            end
        end

      _ ->
        false
    end
  end

  ## Numbers

  def number_to_string(number) when is_integer(number) do
    Number.Delimit.number_to_delimited(number)
  end

  def number_to_string(number) when is_float(number) do
    Number.Delimit.number_to_delimited(number)
  end

  def number_to_string(number), do: to_string(number)

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
    case payload do
      nil ->
        nil

      "" ->
        nil

      _ ->
        case Encrypted.Users.Utils.decrypt_user_item(
               payload,
               user,
               item_key,
               key
             ) do
          :failed_verification ->
            "failed_verification"

          decrypted_payload ->
            decrypted_payload
        end
    end
  end

  def decr_banner(payload, user, item_key, key) do
    case payload do
      nil ->
        nil

      "" ->
        nil

      _ ->
        case Encrypted.Users.Utils.decrypt_user_item(
               payload,
               user,
               item_key,
               key
             ) do
          :failed_verification ->
            "failed_verification"

          decrypted_payload ->
            decrypted_payload
        end
    end
  end

  def maybe_decr_username_for_user_group(user_id, current_user, key) do
    uconn = get_uconn_for_users!(user_id, current_user.id)

    cond do
      is_nil(uconn) && user_id != current_user.id ->
        "Private"

      is_nil(uconn) && user_id == current_user.id ->
        if current_user.decrypted,
          do: current_user.decrypted[:username],
          else: decr(current_user.username, current_user, key)

      true ->
        decr_uconn(uconn.connection.username, current_user, uconn.key, key)
    end
  end

  def decr_item(payload, user, item_key, key, item \\ nil, string_name \\ nil) do
    cond do
      group?(item) && item.public? ->
        owner_key = Enum.find(item.user_groups, &(&1.role == :owner)).key
        decr_public_item(payload, owner_key)

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

                case Encrypted.Users.Utils.decrypt_user_attrs_key(user_group.key, user, key) do
                  {:ok, d_group_key} ->
                    Encrypted.Users.Utils.decrypt_group_item(payload, d_group_key)

                  _error ->
                    "[encrypted]"
                end
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

          Encrypted.Users.Utils.decrypt_item(payload, user, user_group.key, key)
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

                case Encrypted.Users.Utils.decrypt_user_attrs_key(user_group.key, user, key) do
                  {:ok, d_group_key} ->
                    Encrypted.Users.Utils.decrypt_group_item(payload, d_group_key)

                  _error ->
                    "[encrypted]"
                end
              end

            _rest ->
              Encrypted.Users.Utils.decrypt_item(payload, user, item_key, key)
          end
        end

      true ->
        "did not work"
    end
  end

  @doc """
  Unseals the raw post_key for a post, performing the expensive asymmetric
  crypto only once. Returns `{:ok, raw_key}` or `:error`.

  For public posts, unseals using the server keypair.
  For non-public posts, unseals using the current user's keypair.
  Handles the group_id edge case where the key comes from user_group.
  """
  def unseal_post_key(post, current_user, session_key) do
    sealed_key =
      case post.visibility do
        :public -> get_post_key(post)
        _ -> get_post_key(post, current_user)
      end

    if is_nil(sealed_key) do
      :error
    else
      case post.visibility do
        :public ->
          case Encrypted.Users.Utils.decrypt_public_item_key(sealed_key) do
            raw_key when is_binary(raw_key) -> {:ok, raw_key}
            _ -> :error
          end

        _ ->
          case Encrypted.Users.Utils.decrypt_user_attrs_key(sealed_key, current_user, session_key) do
            {:ok, raw_key} -> {:ok, raw_key}
            _ -> :error
          end
      end
    end
  end

  @doc """
  Decrypts a single field payload using an already-unsealed raw post_key.
  Returns the plaintext string, or the fallback on failure.
  """
  def decrypt_field(nil, _raw_key, fallback), do: fallback
  def decrypt_field("", _raw_key, _fallback), do: ""
  def decrypt_field(_payload, nil, fallback), do: fallback

  def decrypt_field(payload, raw_key, fallback) do
    case Encrypted.Utils.decrypt(%{key: raw_key, payload: payload}) do
      {:ok, plaintext} -> plaintext
      _ -> fallback
    end
  end

  @doc """
  Returns the plaintext value of a user profile field from the
  pre-decrypted map. When `display?: true` was used at mount time the
  value is already present; when `display?: false` the raw_key is used
  to decrypt on demand. Avoids passing decrypted values through
  `phx-value-*` template attributes.

  Supported fields: `:email`, `:username`, `:name`, `:avatar_url`, `:status_message`.
  """
  def resolve_decrypted_field(%User{decrypted: %{} = d} = user, field)
      when field in [:email, :username, :name, :avatar_url, :status_message] do
    case Map.get(d, field) do
      value when is_binary(value) ->
        value

      _ ->
        raw_key = Map.get(d, :raw_key)
        encrypted = Map.get(user, field)
        decrypt_field(encrypted, raw_key, nil)
    end
  end

  def resolve_decrypted_field(_user, _field), do: nil

  @doc """
  Decrypts all renderable fields of a post in one pass, unsealing the
  post_key only once. Returns a map suitable for template rendering.

  This replaces the per-field `decr_item` calls in the timeline template,
  reducing NIF calls from ~10-13 per post down to 1 unseal + N secretbox ops.

  Fields decrypted:
    - :body, :username, :content_warning, :content_warning_category
    - :image_urls (list), :url_preview (map)
    - :favs_list (list of user IDs), :reposts_list (list of user IDs)
    - :share_note (from user_post)
  """
  def decrypt_post_fields(post, current_user, session_key) do
    sealed_key =
      case post.visibility do
        :public -> get_post_key(post)
        _ -> get_post_key(post, current_user)
      end

    browser_decrypt? = post.visibility != :public

    # Bookmark notes are attached by list_user_bookmarks when on the bookmarks tab.
    # This is an encrypted blob (secretbox with post_key), or nil.
    bookmark_notes_blob = Map.get(post, :bookmark_notes)

    case unseal_post_key(post, current_user, session_key) do
      {:ok, raw_key} ->
        # For non-public posts, pass encrypted blobs to the browser for ZK
        # decryption instead of decrypting server-side. The DecryptPost hook
        # unseals the post_key and decrypts all fields in WASM.
        #
        # For public posts, decrypt everything server-side (server has the
        # server keypair and needs plaintext for SEO/federation/moderation).
        if browser_decrypt? do
          # ZK path: server never sees plaintext for non-public posts.
          # image_urls are still server-decrypted (S3 paths needed for proxy).
          %{
            body: nil,
            username: nil,
            content_warning: if(post.content_warning?, do: nil),
            content_warning_category: if(post.content_warning?, do: nil),
            url_preview: nil,
            image_urls: decrypt_list(post.image_urls, raw_key),
            image_alt_texts: nil,
            favs_list: nil,
            reposts_list: nil,
            share_note: nil,
            bookmark_notes: nil,
            encrypted_bookmark_notes: bookmark_notes_blob,
            raw_key: nil,
            sealed_post_key: sealed_key,
            encrypted_body: post.body,
            encrypted_username: post.username,
            encrypted_content_warning: if(post.content_warning?, do: post.content_warning),
            encrypted_content_warning_category:
              if(post.content_warning?, do: post.content_warning_category),
            encrypted_url_preview: post.url_preview,
            encrypted_favs_list: post.favs_list,
            encrypted_reposts_list: post.reposts_list,
            encrypted_share_note: encrypted_share_note_blob(post, current_user),
            encrypted_image_alt_texts: post.image_alt_texts,
            browser_decrypt?: true
          }
        else
          # Public post: server-side decryption for SEO/federation
          %{
            body: decrypt_field(post.body, raw_key, "[Could not decrypt content]"),
            username: decrypt_field(post.username, raw_key, "author"),
            content_warning:
              if(post.content_warning?,
                do: decrypt_field(post.content_warning, raw_key, nil)
              ),
            content_warning_category:
              if(post.content_warning?,
                do: decrypt_field(post.content_warning_category, raw_key, nil)
              ),
            url_preview: decrypt_url_preview(post.url_preview, raw_key),
            image_urls: decrypt_list(post.image_urls, raw_key),
            image_alt_texts: decrypt_list(post.image_alt_texts, raw_key),
            favs_list: decrypt_id_list(post.favs_list, raw_key),
            reposts_list: decrypt_id_list(post.reposts_list, raw_key),
            share_note: decrypt_share_note(post, current_user, raw_key),
            bookmark_notes: decrypt_bookmark_notes(bookmark_notes_blob, raw_key),
            encrypted_bookmark_notes: nil,
            raw_key: raw_key,
            sealed_post_key: nil,
            encrypted_body: nil,
            encrypted_username: nil,
            encrypted_content_warning: nil,
            encrypted_content_warning_category: nil,
            encrypted_url_preview: nil,
            encrypted_favs_list: nil,
            encrypted_reposts_list: nil,
            encrypted_share_note: nil,
            encrypted_image_alt_texts: nil,
            browser_decrypt?: false
          }
        end

      :error ->
        %{
          body: "[Could not decrypt content]",
          username: "author",
          content_warning: nil,
          content_warning_category: nil,
          image_urls: [],
          image_alt_texts: [],
          url_preview: nil,
          favs_list: [],
          reposts_list: [],
          share_note: nil,
          bookmark_notes: nil,
          encrypted_bookmark_notes: nil,
          raw_key: nil,
          sealed_post_key: nil,
          encrypted_body: nil,
          encrypted_username: nil,
          encrypted_content_warning: nil,
          encrypted_content_warning_category: nil,
          encrypted_url_preview: nil,
          encrypted_favs_list: nil,
          encrypted_reposts_list: nil,
          encrypted_share_note: nil,
          encrypted_image_alt_texts: nil,
          browser_decrypt?: false
        }
    end
  end

  defp decrypt_list(nil, _raw_key), do: []
  defp decrypt_list([], _raw_key), do: []

  defp decrypt_list(items, raw_key) when is_list(items) do
    Enum.map(items, fn item -> decrypt_field(item, raw_key, nil) end)
    |> Enum.reject(&is_nil/1)
  end

  defp decrypt_id_list(nil, _raw_key), do: []
  defp decrypt_id_list([], _raw_key), do: []

  defp decrypt_id_list(items, raw_key) when is_list(items) do
    Enum.map(items, fn item ->
      case Encrypted.Utils.decrypt(%{key: raw_key, payload: item}) do
        {:ok, decrypted_id} -> decrypted_id
        _ -> item
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp decrypt_url_preview(nil, _raw_key), do: nil
  defp decrypt_url_preview(preview, _raw_key) when not is_map(preview), do: nil

  defp decrypt_url_preview(preview, raw_key) do
    alias Mosslet.Extensions.URLPreviewServer
    URLPreviewServer.decrypt_preview_with_key(preview, raw_key)
  end

  defp decrypt_share_note(post, current_user, raw_key) do
    if Ecto.assoc_loaded?(post.user_posts) do
      user_post = Enum.find(post.user_posts, fn up -> up.user_id == current_user.id end)

      if user_post && user_post.share_note do
        decrypt_field(user_post.share_note, raw_key, nil)
      end
    end
  end

  # Returns the encrypted share_note blob (without decrypting) for browser-side ZK.
  defp encrypted_share_note_blob(post, current_user) do
    if Ecto.assoc_loaded?(post.user_posts) do
      user_post = Enum.find(post.user_posts, fn up -> up.user_id == current_user.id end)
      if user_post, do: user_post.share_note
    end
  end

  # Decrypts bookmark notes blob with the post_key (public post path).
  defp decrypt_bookmark_notes(nil, _raw_key), do: nil

  defp decrypt_bookmark_notes(notes_blob, raw_key) do
    decrypt_field(notes_blob, raw_key, nil)
  end

  @doc """
  Pre-decrypts a post and attaches the decrypted fields as a `:decrypted` key
  on the post map. This is designed to be called before streaming posts into
  the LiveView, so the template can read plaintext directly.
  """
  def pre_decrypt_post(%Post{} = post, current_user, session_key) do
    decrypted = decrypt_post_fields(post, current_user, session_key)
    Map.put(post, :decrypted, decrypted)
  end

  def pre_decrypt_post(post, _current_user, _session_key), do: post

  @doc """
  Pre-decrypts a list of posts. See `pre_decrypt_post/3`.
  """
  def pre_decrypt_posts(posts, current_user, session_key) do
    Enum.map(posts, &pre_decrypt_post(&1, current_user, session_key))
  end

  @doc """
  Unseals a group key from a user_group.key binary.

  For public groups the key was sealed with the server's public key;
  for private groups it was sealed with the user's public key.
  Returns `{:ok, raw_key}` or `:error`.
  """
  def unseal_group_key(sealed_key, group, current_user, session_key) do
    if is_nil(sealed_key) do
      :error
    else
      if group.public? do
        case Encrypted.Users.Utils.decrypt_public_item_key(sealed_key) do
          raw_key when is_binary(raw_key) ->
            {:ok, raw_key}

          _ ->
            # The sealed key may be hybrid (v2) if it was created before the
            # public? guard was added to UserGroup.encrypt_attrs. In that case
            # it was sealed to server_public_key + owner.pq_public_key. Try
            # unsealing with the current user's full keypair and, on success,
            # re-seal with BoxSeal to the server's public key so future reads
            # work without this fallback.
            repair_hybrid_public_group_key(sealed_key, group, current_user, session_key)
        end
      else
        case Encrypted.Users.Utils.decrypt_user_attrs_key(sealed_key, current_user, session_key) do
          {:ok, raw_key} -> {:ok, raw_key}
          _ -> :error
        end
      end
    end
  end

  defp repair_hybrid_public_group_key(sealed_key, group, current_user, session_key) do
    case Encrypted.Users.Utils.decrypt_user_attrs_key(sealed_key, current_user, session_key) do
      {:ok, raw_key} ->
        # Re-seal with server's public key only (no PQ) so future reads work
        new_sealed =
          Encrypted.Utils.encrypt_message_for_user_with_pk(raw_key, %{
            public: Encrypted.Session.server_public_key()
          })

        user_group =
          Enum.find(group.user_groups, fn ug ->
            ug.user_id == current_user.id
          end)

        if user_group do
          Groups.update_user_group_key(user_group, new_sealed)
        end

        {:ok, raw_key}

      _ ->
        :error
    end
  end

  @doc """
  Pre-decrypts a group message into a `.decrypted` map.

  For non-public groups, `content` is set to `nil` (browser decrypts it via
  the DecryptGroupMessage hook). For public groups, all fields are server-decrypted.

  The sealed group key and encrypted content are included so the browser can
  perform client-side decryption.
  """
  def pre_decrypt_group_message(message, group, user_group, current_user, session_key) do
    sealed_key = user_group.key
    browser_decrypt? = not group.public?

    case unseal_group_key(sealed_key, group, current_user, session_key) do
      {:ok, raw_key} ->
        sender = message.sender || %{}

        decrypted = %{
          content:
            if(browser_decrypt?,
              do: nil,
              else: decrypt_field(message.content, raw_key, "[Could not decrypt]")
            ),
          moniker: decrypt_field(Map.get(sender, :moniker), raw_key, "member"),
          avatar_img: decrypt_field(Map.get(sender, :avatar_img), raw_key, nil),
          raw_key: raw_key,
          sealed_group_key: if(browser_decrypt?, do: sealed_key),
          encrypted_content: if(browser_decrypt?, do: message.content),
          browser_decrypt?: browser_decrypt?
        }

        Map.put(message, :decrypted, decrypted)

      :error ->
        decrypted = %{
          content:
            if(browser_decrypt?,
              do: nil,
              else: "[Could not decrypt]"
            ),
          moniker: "member",
          avatar_img: nil,
          raw_key: nil,
          sealed_group_key: if(browser_decrypt?, do: sealed_key),
          encrypted_content: if(browser_decrypt?, do: message.content),
          browser_decrypt?: browser_decrypt?
        }

        Map.put(message, :decrypted, decrypted)
    end
  end

  def pre_decrypt_group_messages(messages, group, user_group, current_user, session_key) do
    Enum.map(
      messages,
      &pre_decrypt_group_message(&1, group, user_group, current_user, session_key)
    )
  end

  @doc """
  Pre-decrypts group metadata (name, description, current user's moniker) and
  returns a map with server-decrypted values for public groups and encrypted
  blobs for browser-decrypt groups.

  For non-public groups, the encrypted name/description/moniker are included
  alongside the sealed group key so the DecryptGroupMetadata hook can decrypt
  them browser-side. Server-decrypted values are set to nil.
  """
  def pre_decrypt_group_metadata(group, user_group, current_user, session_key) do
    sealed_key = user_group.key
    browser_decrypt? = not group.public?

    case unseal_group_key(sealed_key, group, current_user, session_key) do
      {:ok, raw_key} ->
        %{
          name:
            if(browser_decrypt?,
              do: nil,
              else: decrypt_field(group.name, raw_key, "Unnamed Circle")
            ),
          description:
            if(browser_decrypt?,
              do: nil,
              else: decrypt_field(group.description, raw_key, "")
            ),
          moniker:
            if(browser_decrypt?,
              do: nil,
              else: decrypt_field(user_group.moniker, raw_key, "member")
            ),
          raw_key: raw_key,
          sealed_group_key: if(browser_decrypt?, do: sealed_key),
          encrypted_name: if(browser_decrypt?, do: group.name),
          encrypted_description: if(browser_decrypt?, do: group.description),
          encrypted_moniker: if(browser_decrypt?, do: user_group.moniker),
          browser_decrypt?: browser_decrypt?
        }

      :error ->
        %{
          name: "Unnamed Circle",
          description: "",
          moniker: "member",
          raw_key: nil,
          sealed_group_key: if(browser_decrypt?, do: sealed_key),
          encrypted_name: if(browser_decrypt?, do: group.name),
          encrypted_description: if(browser_decrypt?, do: group.description),
          encrypted_moniker: if(browser_decrypt?, do: user_group.moniker),
          browser_decrypt?: browser_decrypt?
        }
    end
  end

  @doc """
  Pre-decrypts a journal entry for browser-side ZK rendering.

  Journal entries are encrypted with the user's personal key (user_key).
  Instead of server-side decryption, we pass the encrypted blobs and the
  sealed user_key so the `DecryptJournalEntry` JS hook can decrypt
  client-side.

  Returns the entry with a `:decrypted` map containing:
    - `:encrypted_title`, `:encrypted_body`, `:encrypted_mood` — raw ciphertext blobs
    - `:sealed_user_key` — the user_key sealed to the user's keypair
    - `:browser_decrypt?` — always `true`
  """
  def pre_decrypt_journal_entry(entry, sealed_user_key) do
    Map.put(entry, :decrypted, %{
      encrypted_title: entry.title,
      encrypted_body: entry.body,
      encrypted_mood: entry.mood,
      sealed_user_key: sealed_user_key,
      browser_decrypt?: true
    })
  end

  @doc """
  Pre-decrypts a list of journal entries for browser-side ZK rendering.
  """
  def pre_decrypt_journal_entries(entries, sealed_user_key) do
    Enum.map(entries, &pre_decrypt_journal_entry(&1, sealed_user_key))
  end

  @doc """
  Pre-decrypts the current user's profile fields and attaches them as a
  `:decrypted` map on the user struct.

  The user_key (user_attributes_key) is unsealed once, then each profile
  field is a cheap SecretBox decrypt. Server-decrypted values are kept in the
  map for backend code (profile sync, form handlers, etc.).

  With `browser_decrypt?: true`, templates should use the DecryptUserFields
  JS hook to decrypt in the browser (true ZK for web users). The sealed
  user_key and encrypted field blobs are included for the hook.

  Fields:
    - :email, :username, :name, :avatar_url, :status_message
  """
  def pre_decrypt_user(user, session_key, opts \\ [])

  def pre_decrypt_user(%User{} = user, session_key, opts) do
    display? = Keyword.get(opts, :display?, true)

    case Encrypted.Users.Utils.decrypt_user_attrs_key(user.user_key, user, session_key) do
      {:ok, raw_key} ->
        decrypted = %{
          raw_key: raw_key,
          sealed_user_key: user.user_key,
          sealed_conn_key: user.conn_key,
          encrypted_email: user.email,
          encrypted_username: user.username,
          encrypted_name: user.name,
          encrypted_avatar_url: user.avatar_url,
          encrypted_status_message: user.status_message,
          browser_decrypt?: true
        }

        decrypted =
          if display? do
            Map.merge(decrypted, %{
              email: decrypt_field(user.email, raw_key, nil),
              username: decrypt_field(user.username, raw_key, nil),
              name: decrypt_field(user.name, raw_key, nil),
              avatar_url: decrypt_avatar_field(user.avatar_url, raw_key),
              status_message: decrypt_field(user.status_message, raw_key, nil)
            })
          else
            decrypted
          end

        Map.put(user, :decrypted, decrypted)

      _error ->
        decrypted = %{
          email: nil,
          username: nil,
          name: nil,
          avatar_url: nil,
          status_message: nil,
          raw_key: nil,
          sealed_user_key: user.user_key,
          sealed_conn_key: user.conn_key,
          encrypted_email: user.email,
          encrypted_username: user.username,
          encrypted_name: user.name,
          encrypted_avatar_url: user.avatar_url,
          encrypted_status_message: user.status_message,
          browser_decrypt?: true
        }

        Map.put(user, :decrypted, decrypted)
    end
  end

  def pre_decrypt_user(user, _session_key, _opts), do: user

  @doc """
  Pre-decrypts a ConnectionProfile's fields and returns a map of plaintext values.

  Unseals the profile_key once (1 asymmetric op) then decrypts all text fields
  via cheap SecretBox ops. Handles public profiles (server-key sealed) and
  private/connections profiles (user-key sealed).

  Fields decrypted:
    - :about, :alternate_email, :website_url, :website_label

  Returns a map like `%{about: "...", alternate_email: "...", ...}` or
  `%{about: nil, ...}` on failure.
  """
  def pre_decrypt_profile(nil, _user, _session_key), do: nil

  def pre_decrypt_profile(profile, user, session_key) do
    sealed_key = profile.profile_key

    case unseal_profile_key(sealed_key, profile, user, session_key) do
      {:ok, raw_key} ->
        %{
          about: decrypt_field(profile.about, raw_key, nil),
          alternate_email: decrypt_field(profile.alternate_email, raw_key, nil),
          website_url: decrypt_field(profile.website_url, raw_key, nil),
          website_label: decrypt_field(profile.website_label, raw_key, nil),
          raw_key: raw_key
        }

      :error ->
        %{
          about: nil,
          alternate_email: nil,
          website_url: nil,
          website_label: nil,
          raw_key: nil
        }
    end
  end

  @doc """
  Unseals a profile_key from a ConnectionProfile.

  Public profiles use the server keypair; private/connections profiles
  use the current user's keypair.
  """
  def unseal_profile_key(nil, _profile, _user, _session_key), do: :error

  def unseal_profile_key(sealed_key, profile, user, session_key) do
    if profile.visibility == :public do
      case Encrypted.Users.Utils.decrypt_public_item_key(sealed_key) do
        raw_key when is_binary(raw_key) -> {:ok, raw_key}
        _ -> :error
      end
    else
      case Encrypted.Users.Utils.decrypt_user_attrs_key(sealed_key, user, session_key) do
        {:ok, raw_key} -> {:ok, raw_key}
        _ -> :error
      end
    end
  end

  @doc """
  Decrypts connection profile fields with browser/server dual path.

  For public profiles: server decrypts everything (needed for SEO/unauthenticated).
  For private/connections profiles: returns encrypted blobs + sealed key for
  browser-side ZK decryption via the DecryptProfileFields hook.

  ## Viewing contexts

    - `:own` — user views their own profile. The sealed key is `profile.profile_key`.
    - `:connection` — user views a connection's profile. The sealed key is
      `user_connection.key` (the profile owner's conn_key sealed to the viewer).
    - `:public` — unauthenticated visitor. Always server-side.

  Returns a map with plaintext values (server path) or encrypted blobs + sealed
  key (browser path), plus a `browser_decrypt?` flag.
  """
  def decrypt_profile_fields(profile, user, session_key, opts \\ [])
  def decrypt_profile_fields(nil, _user, _session_key, _opts), do: nil

  def decrypt_profile_fields(profile, user, session_key, opts) do
    viewing = Keyword.get(opts, :viewing, :own)
    uconn_key = Keyword.get(opts, :uconn_key)

    browser_decrypt? = profile.visibility != :public

    sealed_key =
      case viewing do
        :public -> profile.profile_key
        :connection -> uconn_key
        :own -> profile.profile_key
      end

    case unseal_profile_key_for_context(sealed_key, profile, user, session_key, viewing) do
      {:ok, raw_key} ->
        if browser_decrypt? do
          %{
            about: nil,
            alternate_email: nil,
            website_url: nil,
            website_label: nil,
            sealed_profile_key: sealed_key,
            encrypted_about: profile.about,
            encrypted_alternate_email: profile.alternate_email,
            encrypted_website_url: profile.website_url,
            encrypted_website_label: profile.website_label,
            browser_decrypt?: true
          }
        else
          %{
            about: decrypt_field(profile.about, raw_key, nil),
            alternate_email: decrypt_field(profile.alternate_email, raw_key, nil),
            website_url: decrypt_field(profile.website_url, raw_key, nil),
            website_label: decrypt_field(profile.website_label, raw_key, nil),
            sealed_profile_key: nil,
            encrypted_about: nil,
            encrypted_alternate_email: nil,
            encrypted_website_url: nil,
            encrypted_website_label: nil,
            browser_decrypt?: false
          }
        end

      :error ->
        %{
          about: nil,
          alternate_email: nil,
          website_url: nil,
          website_label: nil,
          sealed_profile_key: nil,
          encrypted_about: nil,
          encrypted_alternate_email: nil,
          encrypted_website_url: nil,
          encrypted_website_label: nil,
          browser_decrypt?: false
        }
    end
  end

  defp unseal_profile_key_for_context(nil, _profile, _user, _key, _viewing), do: :error

  defp unseal_profile_key_for_context(sealed_key, _profile, _user, _key, :public) do
    case Encrypted.Users.Utils.decrypt_public_item_key(sealed_key) do
      raw_key when is_binary(raw_key) -> {:ok, raw_key}
      _ -> :error
    end
  end

  # Own profile with public visibility: profile_key is sealed to the server keypair
  defp unseal_profile_key_for_context(sealed_key, %{visibility: :public}, _user, _key, :own) do
    case Encrypted.Users.Utils.decrypt_public_item_key(sealed_key) do
      raw_key when is_binary(raw_key) -> {:ok, raw_key}
      _ -> :error
    end
  end

  defp unseal_profile_key_for_context(sealed_key, _profile, user, session_key, _viewing) do
    case Encrypted.Users.Utils.decrypt_user_attrs_key(sealed_key, user, session_key) do
      {:ok, raw_key} -> {:ok, raw_key}
      _ -> :error
    end
  end

  # Avatar URLs need special handling: nil/empty values are nil,
  # and :failed_verification becomes "failed_verification" string.
  defp decrypt_avatar_field(nil, _raw_key), do: nil
  defp decrypt_avatar_field("", _raw_key), do: nil

  defp decrypt_avatar_field(payload, raw_key) do
    case Encrypted.Utils.decrypt(%{key: raw_key, payload: payload}) do
      {:ok, plaintext} -> plaintext
      _ -> "failed_verification"
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
    case Encrypted.Users.Utils.decrypt_user_attrs_key(payload_key, user, key) do
      {:ok, d_attrs_key} -> d_attrs_key
      _error -> nil
    end
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
  def user_name(%{decrypted: %{name: name}} = _user, _key) when not is_nil(name), do: name
  def user_name(user, key), do: decr(user.name, user, key)

  def username(nil), do: nil
  def username(nil, nil), do: nil
  def username(nil, _key), do: nil

  def username(%{decrypted: %{username: username}} = _user, _key) when not is_nil(username),
    do: username

  def username(user, key), do: decr(user.username, user, key)

  # Use this for decryping a username
  def username(item, user, key) do
    cond do
      item.user_id == user.id ->
        # Current user's own item - use their username
        d_username = if user.decrypted, do: user.decrypted[:username]

        case d_username || decr(user.username, user, key) do
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

  @doc """
  Formats and renders markdown content after decryption.
  Uses MDEx for markdown rendering with syntax highlighting and built-in sanitization.
  """
  def format_decrypted_content(:failed_verification), do: "[Could not decrypt content]"
  def format_decrypted_content(nil), do: ""
  def format_decrypted_content(""), do: ""

  def format_decrypted_content(content) when is_binary(content) do
    content
    |> Mosslet.MarkdownRenderer.to_html()
    |> Phoenix.HTML.raw()
  end

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
        color: uconn.color,
        profile_slug: uconn.connection.profile && uconn.connection.profile.slug,
        profile_visibility: uconn.connection.profile && uconn.connection.profile.visibility
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

  def get_public_user_group(group, user) do
    case Groups.get_user_group_for_group_and_user(group, user) do
      nil -> Enum.at(group.user_groups, 0)
      user_group -> user_group
    end
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
    user_group = Enum.find(group.user_groups, fn ug -> ug.user_id == user.id end)

    cond do
      group.user_id == user.id ->
        true

      user_group && user_group.role == :owner ->
        true

      true ->
        false
    end
  end

  def can_join_group?(group, user_group, user) do
    cond do
      group.public? ->
        true

      user_group && user_group.user_id == user.id &&
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

  def is_shared_recipient?(post, current_user_id) do
    post.shared_users &&
      Enum.any?(post.shared_users, fn shared_user ->
        shared_user.user_id == current_user_id
      end)
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

  def last_unread_post?(post, current_user, options \\ %{}) do
    unread_posts = Timeline.unread_posts(current_user, options)

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

  def can_repost?(user, post) do
    if post.user_id != user.id && user.id not in post.reposts_list do
      true
    else
      false
    end
  end

  # Helper to get the post_key for a reply (same as the post it belongs to)
  def get_reply_post_key(reply, current_user) do
    # Get the post this reply belongs to with user_posts preloaded
    post = Mosslet.Repo.preload(reply, post: :user_posts).post

    # Use the existing get_post_key helper function
    case get_post_key(post, current_user) do
      encrypted_post_key when is_binary(encrypted_post_key) ->
        {:ok, encrypted_post_key}

      _ ->
        {:error, :no_access}
    end
  end

  # Safe version to get reply author name
  def get_safe_reply_author_name(reply, current_user, key) do
    cond do
      reply.user_id == current_user.id ->
        case user_name(current_user, key) do
          name when is_binary(name) -> name
          :failed_verification -> "You"
          _ -> "You"
        end

      not is_connected_to_reply_author?(reply, current_user) ->
        "Private Author"

      true ->
        case get_reply_post_key(reply, current_user) do
          {:ok, post_key} ->
            case decr_item(reply.username, current_user, post_key, key, reply, "username") do
              name when is_binary(name) -> name
              :failed_verification -> "Private Author"
              _ -> "Private Author"
            end

          _ ->
            "Private Author"
        end
    end
  end

  def is_connected_to_reply_author?(reply, current_user) do
    case get_uconn_for_shared_item(reply, current_user) do
      nil -> false
      %Mosslet.Accounts.UserConnection{} -> true
      _ -> false
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
        diff_seconds < 3_600 -> "#{div(diff_seconds, 60)}m"
        diff_seconds < 86_400 -> "#{div(diff_seconds, 3_600)}h"
        true -> "#{div(diff_seconds, 86_400)}d"
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
  Checks if a user can download photos from a shared post/memory.

  When user Dino views Isabella's post, this checks if Isabella has granted
  photos? permission to Dino.

  Args:
    - item: The post/memory being viewed
    - current_user: The user trying to download

  Returns boolean indicating if download is allowed.
  """
  def can_download_photos_from_shared_item?(item, current_user) do
    case Accounts.get_post_author_permissions_for_viewer(item, current_user) do
      %{photos?: true} -> true
      _ -> false
    end
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

  @doc """
  Ensures the avatar for a user or connection is cached in ETS.

  If the avatar is already cached, returns `:ok`.
  If it needs fetching from S3, kicks off an async task and returns the task.
  The `callback_tuple` is the tuple returned to `handle_info` on completion
  (e.g. `{"get_user_avatar", user.id}` or `{"get_user_avatar", item.id, item_list, user.id}`).

  This function only fetches and caches the **encrypted** binary — it never
  decrypts avatar image data. Display is handled by `get_encrypted_avatar_data/2`
  which returns the encrypted blob + sealed key for browser-side ZK decryption.
  """
  def ensure_avatar_cached(%User{} = user, key, callback_tuple) do
    user = preload_connection(user)
    connection_id = user.connection.id

    cond do
      is_nil(user.avatar_url) ->
        :ok

      not is_nil(AvatarProcessor.get_ets_avatar("profile-#{connection_id}")) ->
        :ok

      true ->
        fetch_and_cache_avatar(user.connection, user, user.conn_key, key, callback_tuple)
    end
  end

  def ensure_avatar_cached(%UserConnection{} = uconn, key, callback_tuple) do
    connection_id = uconn.connection.id

    cond do
      is_nil(uconn.connection.avatar_url) ->
        :ok

      not is_nil(AvatarProcessor.get_ets_avatar("profile-#{connection_id}")) ->
        :ok

      true ->
        fetch_and_cache_avatar(uconn.connection, uconn.user, uconn.key, key, callback_tuple)
    end
  end

  def ensure_avatar_cached(nil, _key, _callback_tuple), do: :ok

  @doc """
  Ensures the avatar for any entity is cached in ETS.

  Resolves the entity to a %User{} or %UserConnection{} and delegates
  to `ensure_avatar_cached/3`. Works for Users, UserConnections, and
  any struct with a :user_id field (posts, replies, user_groups, etc.).
  """
  def ensure_avatar_cached_for_item(%User{} = user, key) do
    ensure_avatar_cached(user, key, {"get_user_avatar", user.id})
  end

  def ensure_avatar_cached_for_item(%UserConnection{} = uconn, key) do
    ensure_avatar_cached(uconn, key, {"get_user_avatar", uconn.id})
  end

  def ensure_avatar_cached_for_item(nil, _key), do: :ok

  def ensure_avatar_cached_for_item(%{user_id: _} = item, key, current_user) do
    uconn = get_uconn_for_shared_item(item, current_user)
    if uconn, do: ensure_avatar_cached(uconn, key, {"get_user_avatar", uconn.id})
    :ok
  end

  defp fetch_and_cache_avatar(connection, user, sealed_key, key, callback_tuple) do
    avatars_bucket = Encrypted.Session.avatars_bucket()
    connection_id = connection.id

    Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
      with d_url when is_binary(d_url) and d_url != "" and d_url != "failed_verification" <-
             decr_avatar(connection.avatar_url, user, sealed_key, key),
           {:ok, %{body: obj}} <-
             ExAws.S3.get_object(avatars_bucket, d_url) |> ExAws.request() do
        unless AvatarProcessor.avatar_recently_updated?(connection_id) do
          AvatarProcessor.put_ets_avatar("profile-#{connection_id}", obj)
        end

        callback_tuple
      else
        _ -> "error"
      end
    end)
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
      :teal -> "border-teal-700 dark:border-teal-300 hover:border-teal-500"
      :cyan -> "border-cyan-700 dark:border-cyan-300 hover:border-cyan-500"
      :indigo -> "border-indigo-700 dark:border-indigo-300 hover:border-indigo-500"
      :orange -> "border-orange-700 dark:border-orange-300 hover:border-orange-500"
      :pink -> "border-pink-700 dark:border-pink-300 hover:border-pink-500"
      :purple -> "border-purple-700 dark:border-purple-300 hover:border-purple-500"
      :rose -> "border-rose-700 dark:border-rose-700 hover:border-rose-500"
      :yellow -> "border-yellow-700 dark:border-yellow-300 hover:border-yellow-500"
      :amber -> "border-amber-700 dark:border-amber-300 hover:border-amber-500"
      :slate -> "border-slate-700 dark:border-slate-300 hover:border-slate-500"
      :zinc -> "border-zinc-700 dark:border-zinc-300 hover:border-zinc-500"
      _rest -> "border-emerald-700 dark:border-emerald-300 hover:border-emerald-500"
    end
  end

  def username_link_text_color(color) do
    case color do
      :brand -> "text-emerald-700 dark:text-emerald-300 hover:text-emerald-500"
      :emerald -> "text-emerald-700 dark:text-emerald-300 hover:text-emerald-500"
      :teal -> "text-teal-700 dark:text-teal-300 hover:text-teal-500"
      :cyan -> "text-cyan-700 dark:text-cyan-300 hover:text-cyan-500"
      :indigo -> "text-indigo-700 dark:text-indigo-300 hover:text-indigo-500"
      :orange -> "text-orange-700 dark:text-orange-300 hover:text-orange-500"
      :pink -> "text-pink-700 dark:text-pink-300 hover:text-pink-500"
      :purple -> "text-purple-700 dark:text-purple-300 hover:text-purple-500"
      :rose -> "text-rose-700 dark:text-rose-700 hover:text-rose-500"
      :amber -> "text-amber-700 dark:text-amber-300 hover:text-amber-500"
      :yellow -> "text-yellow-700 dark:text-yellow-300 hover:text-yellow-500"
      :slate -> "text-slate-700 dark:text-slate-300 hover:text-slate-500"
      :zinc -> "text-zinc-700 dark:text-zinc-300 hover:text-zinc-500"
      _rest -> "text-emerald-700 dark:text-emerald-300 hover:text-emerald-500"
    end
  end

  def username_link_text_color_group(color) do
    case color do
      :brand -> "text-emerald-700 dark:text-emerald-300 group-hover:text-emerald-500"
      :emerald -> "text-emerald-700 dark:text-emerald-300 group-hover:text-emerald-500"
      :teal -> "text-teal-700 dark:text-teal-300 group-hover:text-teal-500"
      :cyan -> "text-cyan-700 dark:text-cyan-300 group-hover:text-cyan-500"
      :indigo -> "text-indigo-700 dark:text-indigo-300 group-hover:text-indigo-500"
      :orange -> "text-orange-700 dark:text-orange-300 group-hover:text-orange-500"
      :pink -> "text-pink-700 dark:text-pink-300 group-hover:text-pink-500"
      :purple -> "text-purple-700 dark:text-purple-300 group-hover:text-purple-500"
      :rose -> "text-rose-700 dark:text-rose-700 group-hover:text-rose-500"
      :amber -> "text-amber-700 dark:text-amber-300 group-hover:text-amber-500"
      :yellow -> "text-yellow-700 dark:text-yellow-300 group-hover:text-yellow-500"
      :zinc -> "text-zinc-700 dark:text-zinc-300 group-hover:text-zinc-500"
      :slate -> "text-slate-700 dark:text-slate-300 group-hover:text-slate-500"
      _rest -> "text-emerald-700 dark:text-emerald-300 group-hover:text-emerald-500"
    end
  end

  def username_link_text_color_no_hover(color) do
    case color do
      :brand -> "text-emerald-700 dark:text-emerald-300"
      :emerald -> "text-emerald-700 dark:text-emerald-300"
      :teal -> "text-teal-700 dark:text-teal-300"
      :cyan -> "text-cyan-700 dark:text-cyan-300"
      :indigo -> "text-indigo-700 dark:text-indigo-300"
      :orange -> "text-orange-700 dark:text-orange-300"
      :pink -> "text-pink-700 dark:text-pink-300"
      :purple -> "text-purple-700 dark:text-purple-300"
      :rose -> "text-rose-700 dark:text-rose-700"
      :yellow -> "text-yellow-700 dark:text-yellow-300"
      :amber -> "text-amber-700 dark:text-amber-300"
      :slate -> "text-slate-700 dark:text-slate-300"
      :zinc -> "text-zinc-700 dark:text-zinc-300"
      _rest -> "text-emerald-700 dark:text-emerald-300"
    end
  end

  def badge_color(color) do
    case color do
      :brand ->
        "bg-emerald-50 dark:bg-emerald-900 text-emerald-700 dark:text-emerald-300 ring-emerald-600/20"

      :emerald ->
        "bg-emerald-50 dark:bg-emerald-950 text-emerald-700 dark:text-emerald-300 ring-emerald-600/20"

      :teal ->
        "bg-teal-50 dark:bg-teal-950 text-teal-700 dark:text-teal-300 ring-teal-600/20"

      :cyan ->
        "bg-cyan-50 dark:bg-cyan-950 text-cyan-700 dark:text-cyan-300 ring-cyan-600/20"

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

      :amber ->
        "bg-amber-50 dark:bg-amber-950 text-amber-700 dark:text-amber-300 ring-amber-600/20"

      :slate ->
        "bg-slate-50 dark:bg-slate-950 text-slate-700 dark:text-slate-300 ring-slate-600/20"

      :zinc ->
        "bg-zinc-50 dark:bg-zinc-950 text-zinc-700 dark:text-zinc-300 ring-zinc-600/20"

      _rest ->
        "bg-emerald-50 dark:bg-emerald-950 text-emerald-700 dark:text-emerald-300 ring-emerald-600/20"
    end
  end

  def role_badge_color(role) do
    case role do
      :owner -> "pink"
      :member -> "emerald"
      :admin -> "orange"
      :moderator -> "purple"
      _rest -> "slate"
    end
  end

  def role_badge_color_classes(role) do
    case role do
      :owner ->
        "inline-flex items-center rounded-md bg-pink-100 px-2 py-1 text-xs font-medium text-pink-700 dark:text-pink-300"

      :member ->
        "inline-flex items-center rounded-md bg-emerald-100 px-2 py-1 text-xs font-medium text-emerald-700 dark:bg-emerald-800 dark:text-emerald-300"

      :admin ->
        "inline-flex items-center rounded-md bg-orange-100 px-2 py-1 text-xs font-medium text-orange-700 dark:text-orange-300"

      :moderator ->
        "inline-flex items-center rounded-md bg-purple-100 px-2 py-1 text-xs font-medium text-purple-700 dark:text-purple-300"

      _rest ->
        "inline-flex items-center rounded-md bg-slate-100 px-2 py-1 text-xs font-medium text-slate-700"
    end
  end

  def role_badge_color_ring(role) do
    case role do
      :owner ->
        "rounded-md bg-pink-50 dark:bg-pink-900 px-2 py-1 text-xs font-medium text-pink-600 dark:text-pink-400 ring-1 ring-inset ring-pink-600/20"

      :member ->
        "rounded-md bg-emerald-50 dark:bg-emerald-900 px-2 py-1 text-xs font-medium text-emerald-600 dark:text-emerald-400 ring-1 ring-inset ring-emerald-600/20"

      :admin ->
        "rounded-md bg-orange-50 px-2 py-1 text-xs font-medium text-orange-600 ring-1 ring-inset ring-orange-600/20"

      :moderator ->
        "rounded-md bg-purple-50 px-2 py-1 text-xs font-medium text-purple-600 ring-1 ring-inset ring-purple-600/20"

      _rest ->
        "rounded-md bg-slate-50 px-2 py-1 text-xs font-medium text-slate-600 ring-1 ring-inset ring-slate-600/20"
    end
  end

  @doc """
  Used to style the avatar in the list of groups
  on the index page of Group Live, using the .group_avatar function.
  """
  def group_avatar_role_style(role) do
    case role do
      :owner ->
        "relative z-30 inline-block h-8 w-8 rounded-full ring-2 ring-pink-600 dark:ring-pink-400 bg-white dark:bg-gray-950"

      :member ->
        "relative z-30 inline-block h-8 w-8 rounded-full ring-2 ring-emerald-600 dark:ring-emerald-400 bg-white dark:bg-gray-950"

      :admin ->
        "relative z-30 inline-block h-8 w-8 rounded-full ring-2 ring-orange-600 dark:ring-orange-400 bg-white dark:bg-gray-950"

      :moderator ->
        "relative z-30 inline-block h-8 w-8 rounded-full ring-2 ring-purple-600 dark:ring-purple-400 bg-white dark:bg-gray-950"

      _rest ->
        "relative z-30 inline-block h-8 w-8 rounded-full ring-2 ring-slate-600 dark:ring-slate-400 bg-white dark:bg-gray-950"
    end
  end

  @doc """
  Used to style the fingerprint in the list of groups
  on the index page of Group Live.
  """
  def group_fingerprint_role_style(role) do
    case role do
      :owner ->
        "text-pink-600 dark:text-pink-400 text-xs"

      :member ->
        "text-emerald-600 dark:text-emerald-400 text-xs"

      :admin ->
        "text-orange-600 dark:text-orange-400 text-xs"

      :moderator ->
        "text-purple-600 dark:text-purple-400 text-xs"

      _rest ->
        "text-slate-600 dark:text-slate-400 text-xs"
    end
  end

  def badge_group_hover_color(color) do
    case color do
      :brand -> "group-hover:text-emerald-700 dark:group-hover:text-emerald-300"
      :emerald -> "group-hover:text-emerald-700 dark:group-hover:text-emerald-300"
      :teal -> "group-hover:text-teal-700 dark:group-hover:text-teal-300"
      :cyan -> "group-hover:text-cyan-700 dark:group-hover:text-cyan-300"
      :indigo -> "group-hover:text-indigo-700 dark:group-hover:text-indigo-300"
      :orange -> "group-hover:text-orange-700 dark:group-hover:text-orange-300"
      :pink -> "group-hover:text-pink-700 dark:group-hover:text-pink-300"
      :purple -> "group-hover:text-purple-700 dark:group-hover:text-purple-300"
      :rose -> "group-hover:text-rose-700 dark:group-hover:text-rose-700"
      :yellow -> "group-hover:text-yellow-700 dark:group-hover:text-yellow-300"
      :amber -> "group-hover:text-amber-700 dark:group-hover:text-amber-300"
      :zinc -> "group-hover:text-zinc-700 dark:group-hover:text-zinc-300"
      :slate -> "group-hover:text-slate-700 dark:group-hover:text-slate-300"
      _rest -> "group-hover:text-emerald-700 dark:group-hover:text-emerald-300"
    end
  end

  def badge_svg_fill_color(color) do
    case color do
      :brand -> "fill-brand-500"
      :emerald -> "fill-emerald-500"
      :teal -> "fill-teal-500"
      :cyan -> "fill-cyan-500"
      :indigo -> "fill-indigo-500"
      :orange -> "fill-orange-500"
      :pink -> "fill-pink-500"
      :purple -> "fill-purple-500"
      :rose -> "fill-rose-500"
      :yellow -> "fill-yellow-500"
      :amber -> "fill-amber-500"
      :zinc -> "fill-zinc-500"
      :slate -> "fill-slate-500"
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

  @doc """
  Returns whether the current user has liked a post.
  Properly handles decryption of the favs_list for encrypted posts.
  """
  def get_post_liked_status(post, current_user, key) do
    if is_nil(key) do
      false
    else
      decrypted_favs = decrypt_post_favs_list(post, current_user, key)
      current_user.id in decrypted_favs
    end
  end

  @doc """
  Decrypts the favs_list for a post based on its visibility.
  Returns a list of decrypted user IDs.
  """
  def decrypt_post_favs_list(post, user, key) do
    case post.favs_list do
      nil ->
        []

      [] ->
        []

      list when is_list(list) ->
        encrypted_post_key =
          case post.visibility do
            :public -> get_post_key(post)
            _ -> get_post_key(post, user)
          end

        if is_nil(encrypted_post_key) do
          []
        else
          case post.visibility do
            :public ->
              case Encrypted.Users.Utils.decrypt_public_item_key(encrypted_post_key) do
                decrypted_post_key when is_binary(decrypted_post_key) ->
                  Enum.map(list, fn user_id ->
                    case Encrypted.Utils.decrypt(%{key: decrypted_post_key, payload: user_id}) do
                      {:ok, decrypted_id} -> decrypted_id
                      _ -> user_id
                    end
                  end)
                  |> Enum.reject(&is_nil/1)

                _ ->
                  []
              end

            _ ->
              case Encrypted.Users.Utils.decrypt_user_attrs_key(encrypted_post_key, user, key) do
                {:ok, decrypted_post_key} ->
                  Enum.map(list, fn user_id ->
                    case Encrypted.Utils.decrypt(%{key: decrypted_post_key, payload: user_id}) do
                      {:ok, decrypted_id} -> decrypted_id
                      _ -> user_id
                    end
                  end)
                  |> Enum.reject(&is_nil/1)

                _ ->
                  []
              end
          end
        end
    end
  end

  @doc """
  Returns whether the current user has liked a reply.
  Properly handles decryption of the favs_list for encrypted replies.
  """
  def get_reply_liked_status(reply, post, current_user, key) do
    if is_nil(key) do
      false
    else
      decrypted_favs = decrypt_reply_favs_list(reply, post, current_user, key)
      current_user.id in decrypted_favs
    end
  end

  @doc """
  Decrypts the favs_list for a reply based on its parent post's visibility.
  Returns a list of decrypted user IDs.
  """
  def decrypt_reply_favs_list(reply, post, user, key) do
    case reply.favs_list do
      nil ->
        []

      [] ->
        []

      list when is_list(list) ->
        encrypted_post_key =
          case post.visibility do
            :public -> get_post_key(post)
            _ -> get_post_key(post, user)
          end

        if is_nil(encrypted_post_key) do
          []
        else
          case post.visibility do
            :public ->
              case Encrypted.Users.Utils.decrypt_public_item_key(encrypted_post_key) do
                decrypted_post_key when is_binary(decrypted_post_key) ->
                  Enum.map(list, fn user_id ->
                    case Encrypted.Utils.decrypt(%{key: decrypted_post_key, payload: user_id}) do
                      {:ok, decrypted_id} -> decrypted_id
                      _ -> user_id
                    end
                  end)
                  |> Enum.reject(&is_nil/1)

                _ ->
                  []
              end

            _ ->
              case Encrypted.Users.Utils.decrypt_user_attrs_key(encrypted_post_key, user, key) do
                {:ok, decrypted_post_key} ->
                  Enum.map(list, fn user_id ->
                    case Encrypted.Utils.decrypt(%{key: decrypted_post_key, payload: user_id}) do
                      {:ok, decrypted_id} -> decrypted_id
                      _ -> user_id
                    end
                  end)
                  |> Enum.reject(&is_nil/1)

                _ ->
                  []
              end
          end
        end
    end
  end

  @doc """
  Returns soft, affirming text for displaying likes.
  Shows warm human messaging instead of quantified counts.

  - If the user has liked it: "You appreciate this"
  - If others have liked it: "People appreciate this"
  - If no likes: nil
  """
  def soft_like_text(0, _liked), do: nil
  def soft_like_text(_count, true), do: "You appreciate"
  def soft_like_text(_count, false), do: "People appreciate"
  def soft_like_text(count), do: soft_like_text(count, false)

  @doc """
  Returns encrypted avatar blob + sealed key for browser-side ZK decryption.

  Fetches the encrypted avatar from ETS cache (already populated by the
  existing avatar fetch/display flow) and returns the sealed conn_key
  so the browser can unseal and decrypt without server involvement.

  Returns `%{encrypted_blob_b64: string, sealed_key: string}` or `nil`.

  The ETS-cached avatar is a raw binary (secretbox ciphertext fetched from S3
  or decoded from the browser's base64 upload). We base64-encode it here so
  the template can safely embed it in an HTML data attribute.
  """
  def get_encrypted_avatar_data(%User{} = user, _key) do
    user = preload_connection(user)

    cond do
      is_nil(user.avatar_url) ->
        nil

      blob = AvatarProcessor.get_ets_avatar("profile-#{user.connection.id}") ->
        %{
          encrypted_blob_b64: ensure_base64(blob),
          sealed_key: user.conn_key
        }

      true ->
        nil
    end
  end

  def get_encrypted_avatar_data(%UserConnection{} = uconn, _key) do
    conn = uconn.connection

    cond do
      is_nil(conn.avatar_url) ->
        nil

      blob = AvatarProcessor.get_ets_avatar("profile-#{conn.id}") ->
        %{
          encrypted_blob_b64: ensure_base64(blob),
          sealed_key: uconn.key
        }

      true ->
        nil
    end
  end

  def get_encrypted_avatar_data(nil, _key), do: nil

  @doc """
  Resolves encrypted avatar data for any entity that references a user:
  %User{}, %UserConnection{}, or any struct with a :user_id field (posts, replies, etc.).

  For items with :user_id, resolves via `get_uconn_for_shared_item/2` and respects
  `show_avatar?/1` privacy settings. Returns `nil` for non-connections and when
  the avatar is hidden.

  This is the single entry point for migrating all `maybe_get_avatar_src`,
  `maybe_get_user_avatar`, and `get_user_avatar` callers to ZK architecture.
  """
  def get_encrypted_avatar_data_for_item(%User{} = user, _current_user) do
    get_encrypted_avatar_data(user, nil)
  end

  def get_encrypted_avatar_data_for_item(%UserConnection{} = uconn, _current_user) do
    if show_avatar?(uconn),
      do: get_encrypted_avatar_data(uconn, nil),
      else: nil
  end

  def get_encrypted_avatar_data_for_item(%{user_id: user_id} = item, %User{} = current_user) do
    if user_id == current_user.id do
      get_encrypted_avatar_data(current_user, nil)
    else
      uconn = get_uconn_for_shared_item(item, current_user)

      if uconn && show_avatar?(uconn),
        do: get_encrypted_avatar_data(uconn, nil),
        else: nil
    end
  end

  def get_encrypted_avatar_data_for_item(nil, _current_user), do: nil

  @doc """
  Returns encrypted banner blob + sealed key for browser-side ZK decryption.

  Same as get_encrypted_avatar_data — ETS stores raw binary, we base64-encode.
  """
  def get_encrypted_banner_data(%User{} = user, _key) do
    user = preload_connection(user)
    profile = Map.get(user.connection, :profile)

    cond do
      is_nil(profile) or is_nil(profile.custom_banner_url) ->
        nil

      blob = BannerProcessor.get_banner(user.connection.id) ->
        %{
          encrypted_blob_b64: ensure_base64(blob),
          sealed_key: user.conn_key
        }

      true ->
        nil
    end
  end

  def get_encrypted_banner_data(_, _key), do: nil

  # ETS stores raw binary blobs. HTML data attributes require UTF-8 text,
  # so we base64-encode before embedding. If the value is already a valid
  # base64 string (e.g. from an older code path), pass it through as-is.
  defp ensure_base64(blob) when is_binary(blob) do
    if String.valid?(blob) and match?({:ok, _}, Base.decode64(blob)) do
      blob
    else
      Base.encode64(blob)
    end
  end

  defp ensure_base64(nil), do: nil
end

defmodule MetamorphicWeb.Helpers do
  @moduledoc false

  alias Metamorphic.Accounts
  alias Metamorphic.Accounts.{User, UserConnection}
  alias Metamorphic.Encrypted
  alias Metamorphic.Extensions.{AvatarProcessor, MemoryProcessor}
  alias Metamorphic.Memories
  alias Metamorphic.Memories.{Memory, Remark}
  alias Metamorphic.Timeline.Post

  ## Numbers

  def number_to_string(number) do
    case Metamorphic.Cldr.Number.to_string(number) do
      {:ok, string} ->
        string

      _rest ->
        nil
    end
  end

  ## Subscriptions

  def get_subscription(user) do
    subscription =
      Bling.Customers.subscription(user) |> Metamorphic.Repo.preload(:subscription_items)

    subscription
  end

  def get_plan(subscription) do
    subscription_items = Bling.Subscriptions.subscription_items(subscription)

    case Enum.count(subscription_items) do
      1 ->
        Bankroll.plan_from_price_id(List.first(subscription_items).stripe_price_id)

      _rest ->
        nil
    end
  end

  ## Conversations

  def assign_ai_tokens(user) do
    subscription = get_subscription(user)
    plan = get_plan(subscription)

    case plan.title do
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
    if(user.ai_tokens == tokens) do
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

  def decr_item(payload, user, item_key, key, item \\ nil) do
    cond do
      item && item.visibility == :public ->
        decr_public_item(payload, item_key)

      item && item.visibility == :private ->
        Encrypted.Users.Utils.decrypt_user_item(payload, user, item_key, key)

      item && item.visibility == :connections && item.user_id == user.id ->
        Encrypted.Users.Utils.decrypt_user_item(payload, user, item_key, key)

      item && item.visibility == :connections && item.user_id != user.id ->
        uconn = get_uconn_for_shared_item(item, user)
        maybe_decrypt_item_with_uconn(payload, uconn, item, user, key)

      true ->
        "did not work"
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
        "You are not connected to this person."

      _rest ->
        data
    end
  end

  defp maybe_decrypt_item_with_uconn(payload, uconn, item, user, key) do
    case uconn do
      nil ->
        if item do
          Encrypted.Users.Utils.decrypt_user_item(payload, user, get_remark_key(item, user), key)
        end

      _rest ->
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

  def decr_attrs_key(payload_key, user, key) do
    {:ok, d_attrs_key} = Encrypted.Users.Utils.decrypt_user_attrs_key(payload_key, user, key)
    d_attrs_key
  end

  ## General

  def now() do
    Date.utc_today()
  end

  def can_edit?(user, item) when is_struct(item) do
    if user.id == item.user_id, do: true
  end

  def can_edit?(user, item) when is_map(item) do
    if user.id == item["user_id"], do: true
  end

  ## Posts

  def get_user_from_post(post) do
    Accounts.get_user_from_post(post)
  end

  def can_fav?(user, item) do
    if user.id not in item.favs_list do
      true
    else
      false
    end
  end

  def can_repost?(user, post) do
    if post.user_id != user.id && user.id not in post.reposts_list do
      true
    else
      false
    end
  end

  def get_user!(id), do: Accounts.get_user!(id)
  def get_user_with_preloads(id), do: Accounts.get_user_with_preloads(id)

  def get_item_connection(item, current_user) do
    cond do
      item && item.visibility == :public ->
        item

      true ->
        Accounts.get_connection_from_item(item, current_user)
    end
  end

  def get_memory_key(memory) do
    Enum.at(memory.user_memories, 0).key
  end

  def get_memory_key(memory, current_user) do
    cond do
      memory.visibility == :connections && current_user.id != memory.user_id ->
        uconn = get_uconn_for_shared_item(memory, current_user)
        uconn.key

      memory.visibility == :private ->
        current_user.conn_key

      true ->
        Enum.at(memory.user_memories, 0).key
    end
  end

  def get_remark_key(remark, current_user) do
    memory = Memories.preload(remark.memory)

    cond do
      memory.visibility == :connections &&
          (current_user.id != memory.user_id &&
             remark.user_id != current_user.id) ->
        uconn = get_uconn_for_shared_item(remark, current_user)
        maybe_get_uconn_key(uconn, memory)

      memory.visibility == :connections &&
          (current_user.id == memory.user_id &&
             remark.user_id == current_user.id) ->
        current_user.conn_key

      memory.visibility == :connections &&
          (current_user.id != memory.user_id &&
             remark.user_id == current_user.id) ->
        current_user.conn_key

      memory.visibility == :connections &&
          (current_user.id == memory.user_id &&
             memory.visibility == :private) ->
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
      post.visibility == :connections && current_user.id != post.user_id ->
        uconn = get_uconn_for_shared_item(post, current_user)
        uconn.key

      post.visibility == :private ->
        current_user.conn_key

      true ->
        Enum.at(post.user_posts, 0).key
    end
  end

  def get_shared_item_identity_atom(item, user) do
    cond do
      item.visibility == :connections && item.user_id == user.id ->
        :self

      item.visibility == :connections && item.user_id != user.id &&
          user_in_item_connections(item, user) ->
        :connection

      true ->
        :invalid
    end
  end

  def get_shared_post_label(post, user, key) do
    cond do
      %UserConnection{} = uconn = get_uconn_for_shared_item(post, user) ->
        Encrypted.Users.Utils.decrypt_user_item(
          uconn.label,
          user,
          uconn.key,
          key
        )

      true ->
        "nil"
    end
  end

  def get_shared_memory_label(memory, user, key) do
    cond do
      %UserConnection{} = uconn = get_uconn_for_shared_item(memory, user) ->
        Encrypted.Users.Utils.decrypt_user_item(
          uconn.label,
          user,
          uconn.key,
          key
        )

      true ->
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

  def is_my_post?(post, user) do
    unless is_nil(user) do
      post.user_id == user.id
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
  # item.user_id, then we return the user and not
  # the uconn.
  def get_uconn_for_shared_item(item, user) do
    if item.user_id == user.id do
      user
    else
      Accounts.get_user_connection_from_shared_item(item, user)
    end
  end

  defp user_in_item_connections(item, user) do
    uconns = Accounts.get_all_user_connections_from_shared_item(item, user)
    Enum.any?(uconns, fn uconn -> uconn.user_id == user.id end)
  end

  def is_users_shared_post?(post, user) do
    cond do
      post.visibility == :connections && post.user_id == user.id ->
        true

      true ->
        false
    end
  end

  ## UserConnections

  def get_uconn_for_users(user, current_user) do
    Accounts.get_user_connection_between_users(user, current_user)
  end

  def get_uconn_for_users!(user_id, current_user_id) do
    Accounts.get_user_connection_between_users!(user_id, current_user_id)
  end

  ## Avatars

  def get_user_avatar(user, key, post \\ nil, current_user \\ nil)

  def get_user_avatar(nil, _key, _post, _current_user), do: nil

  def get_user_avatar(%User{} = user, key, _post, _current_user) do
    user = preload_connection(user)

    cond do
      is_nil(user.avatar_url) ->
        nil

      not is_nil(avatar_binary = AvatarProcessor.get_ets_avatar(user.connection.id)) ->
        image =
          decr_avatar(
            avatar_binary,
            user,
            user.conn_key,
            key
          )
          |> Base.encode64()

        "data:image/jpg;base64," <> image

      is_nil(_avatar_binary = AvatarProcessor.get_ets_avatar(user.connection.id)) ->
        avatars_bucket = Encrypted.Session.avatars_bucket()

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
             decrypted_obj <-
               decr_avatar(
                 obj,
                 user,
                 user.conn_key,
                 key
               ) do
          # Put the encrypted avatar binary in ets.
          Task.Supervisor.async_nolink(Metamorphic.StorjTask, fn ->
            AvatarProcessor.put_ets_avatar(user.connection.id, obj)

            {:ok, :encrypted_profile_avatar_put_in_ets}
          end)

          image = decrypted_obj |> Base.encode64()
          path = "data:image/jpg;base64," <> image
          path
        else
          {:error, _rest} ->
            "error"
        end
    end
  end

  def get_user_avatar(%UserConnection{} = uconn, key, item, current_user) do
    case item do
      nil ->
        # Handle decrypting the avatar for the user connection.
        cond do
          is_nil(uconn.connection.avatar_url) ->
            ""

          not is_nil(avatar_binary = AvatarProcessor.get_ets_avatar(uconn.connection.id)) ->
            image = decrypt_user_or_uconn_binary(avatar_binary, uconn, nil, key, nil)
            "data:image/jpg;base64," <> image

          is_nil(_avatar_binary = AvatarProcessor.get_ets_avatar(uconn.connection.id)) ->
            avatars_bucket = Encrypted.Session.avatars_bucket()

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
                 decrypted_obj <-
                   decr_avatar(
                     obj,
                     uconn.user,
                     uconn.key,
                     key
                   ) do
              # Put the encrypted avatar binary in ets.
              Task.Supervisor.async_nolink(Metamorphic.StorjTask, fn ->
                AvatarProcessor.put_ets_avatar(uconn.connection.id, obj)

                {:ok, :encrypted_profile_avatar_put_in_ets}
              end)

              image = decrypted_obj |> Base.encode64()
              path = "data:image/jpg;base64," <> image
              path
            else
              {:error, _rest} ->
                "error"
            end
        end

      %Post{} = post ->
        # we handle decrypting the avatar for the user connection and
        # possibly the current user if the post is their own.
        cond do
          is_nil(uconn.connection.avatar_url) ->
            ""

          not is_nil(avatar_binary = AvatarProcessor.get_ets_avatar(uconn.connection.id)) ->
            image = decrypt_user_or_uconn_binary(avatar_binary, uconn, post, key, current_user)
            "data:image/jpg;base64," <> image

          is_nil(_avatar_binary = AvatarProcessor.get_ets_avatar(uconn.connection.id)) &&
            not is_nil(current_user) && current_user != post.user_id ->
            avatars_bucket = Encrypted.Session.avatars_bucket()

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
                 decrypted_obj <-
                   decr_avatar(
                     obj,
                     uconn.user,
                     uconn.key,
                     key
                   ) do
              # Put the encrypted avatar binary in ets.
              Task.Supervisor.async_nolink(Metamorphic.StorjTask, fn ->
                AvatarProcessor.put_ets_avatar(uconn.connection.id, obj)

                {:ok, :encrypted_profile_avatar_put_in_ets}
              end)

              image = decrypted_obj |> Base.encode64()
              path = "data:image/jpg;base64," <> image
              path
            else
              {:error, _rest} ->
                "error"
            end

          is_nil(_avatar_binary = AvatarProcessor.get_ets_avatar(uconn.connection.id)) &&
            not is_nil(current_user) && current_user.id == post.user_id ->
            avatars_bucket = Encrypted.Session.avatars_bucket()

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
                 decrypted_obj <-
                   decr_avatar(
                     obj,
                     current_user,
                     uconn.key,
                     key
                   ) do
              # Put the encrypted avatar binary in ets.
              Task.Supervisor.async_nolink(Metamorphic.StorjTask, fn ->
                AvatarProcessor.put_ets_avatar(uconn.connection.id, obj)

                {:ok, :encrypted_profile_avatar_put_in_ets}
              end)

              image = decrypted_obj |> Base.encode64()
              path = "data:image/jpg;base64," <> image
              path
            else
              {:error, _rest} ->
                "error"
            end
        end

      %Remark{} = _remark ->
        # Handle decrypting the avatar for the user connection.
        cond do
          is_nil(uconn.connection.avatar_url) ->
            ""

          not is_nil(avatar_binary = AvatarProcessor.get_ets_avatar(uconn.connection.id)) ->
            image = decrypt_user_or_uconn_binary(avatar_binary, uconn, nil, key, nil)
            "data:image/jpg;base64," <> image

          is_nil(_avatar_binary = AvatarProcessor.get_ets_avatar(uconn.connection.id)) ->
            avatars_bucket = Encrypted.Session.avatars_bucket()

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
                 decrypted_obj <-
                   decr_avatar(
                     obj,
                     uconn.user,
                     uconn.key,
                     key
                   ) do
              # Put the encrypted avatar binary in ets.
              Task.Supervisor.async_nolink(Metamorphic.StorjTask, fn ->
                AvatarProcessor.put_ets_avatar(uconn.connection.id, obj)

                {:ok, :encrypted_profile_avatar_put_in_ets}
              end)

              image = decrypted_obj |> Base.encode64()
              path = "data:image/jpg;base64," <> image
              path
            else
              {:error, _rest} ->
                "error"
            end
        end
    end
  end

  def get_public_user_avatar(user, profile) when is_map(profile) do
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

        with {:ok, %{body: obj}} <-
               ExAws.S3.get_object(
                 avatars_bucket,
                 d_url
               )
               |> ExAws.request(),
             decrypted_obj <-
               decr_public_item(
                 obj,
                 profile.profile_key
               ) do
          # Put the encrypted avatar binary in ets.
          Task.Supervisor.async_nolink(Metamorphic.StorjTask, fn ->
            AvatarProcessor.put_ets_avatar("profile-#{user.connection.id}", obj)

            {:ok, :encrypted_profile_avatar_put_in_ets}
          end)

          image = decrypted_obj |> Base.encode64()
          path = "data:image/jpg;base64," <> image
          path
        else
          {:error, _rest} ->
            with {:ok, %{body: obj}} <-
                   ExAws.S3.get_object(
                     avatars_bucket,
                     d_url
                   )
                   |> ExAws.request(),
                 decrypted_obj <-
                   decr_public_item(
                     obj,
                     profile.profile_key
                   ) do
              # Put the encrypted avatar binary in ets.
              Task.Supervisor.async_nolink(Metamorphic.StorjTask, fn ->
                AvatarProcessor.put_ets_avatar("profile-#{user.connection.id}", obj)

                {:ok, :encrypted_profile_avatar_put_in_ets}
              end)

              image = decrypted_obj |> Base.encode64()
              path = "data:image/jpg;base64," <> image
              path
            else
              {:error, _rest} ->
                ""
            end
        end
    end
  end

  ## Memories

  def assign_plan_memories(user) do
    subscription = get_subscription(user)
    plan = get_plan(subscription)

    case plan.title do
      "Starter" ->
        50

      "Lite" ->
        500

      "Plus" ->
        5_000

      "Pro" ->
        10_000

      "Pro AI" ->
        50_000

      _rest ->
        0
    end
  end

  def get_user_memory(user, key, memory \\ nil, current_user \\ nil)

  def get_user_memory(nil, _key, _memory, _current_user), do: nil

  def get_user_memory(%User{} = user, key, memory, _current_user) do
    user = preload_connection(user)

    cond do
      is_nil(memory.memory_url) ->
        nil

      not is_nil(
        memory_binary =
            MemoryProcessor.get_ets_memory(
              "user:#{user.id}-memory:#{memory.id}-key:#{user.connection.id}"
            )
      ) ->
        image =
          decr_item(
            memory_binary,
            user,
            user.conn_key,
            key,
            memory
          )
          |> Base.encode64()

        "data:image/jpg;base64," <> image

      is_nil(
        _memory_binary =
            MemoryProcessor.get_ets_memory(
              "user:#{user.id}-memory:#{memory.id}-key:#{user.connection.id}"
            )
      ) ->
        memories_bucket = Encrypted.Session.memories_bucket()

        with {:ok, %{body: obj}} <-
               ExAws.S3.get_object(
                 memories_bucket,
                 decr_item(
                   memory.memory_url,
                   user,
                   get_memory_key(memory),
                   key,
                   memory
                 )
               )
               |> ExAws.request(),
             decrypted_obj <-
               decr_item(
                 obj,
                 user,
                 user.conn_key,
                 key,
                 memory
               ) do
          # Put the encrypted memory binary in ets.
          Task.Supervisor.async_nolink(Metamorphic.StorjTask, fn ->
            MemoryProcessor.put_ets_memory(
              "user:#{user.id}-memory:#{memory.id}-key:#{user.connection.id}",
              obj
            )
          end)

          image = decrypted_obj |> Base.encode64()
          path = "data:image/jpg;base64," <> image
          path
        else
          {:error, _rest} ->
            "error"
        end
    end
  end

  def get_user_memory(%UserConnection{} = uconn, key, memory, current_user) do
    case memory do
      nil ->
        nil

      %Memory{} = memory ->
        # we handle decrypting the memory for the user connection and
        # possibly the current user if the memory is their own.
        cond do
          not is_nil(
            memory_binary =
                MemoryProcessor.get_ets_memory(
                  "user:#{memory.user_id}-memory:#{memory.id}-key:#{uconn.connection.id}"
                )
          ) ->
            image = decrypt_memory_binary(memory_binary, uconn, memory, key, current_user)
            "data:image/jpg;base64," <> image

          is_nil(
            _memory_binary =
                MemoryProcessor.get_ets_memory(
                  "user:#{memory.user_id}-memory:#{memory.id}-key:#{uconn.connection.id}"
                )
          ) &&
            not is_nil(current_user) && current_user != memory.user_id ->
            memories_bucket = Encrypted.Session.memories_bucket()

            with {:ok, %{body: obj}} <-
                   ExAws.S3.get_object(
                     memories_bucket,
                     decr_item(
                       memory.memory_url,
                       uconn.user,
                       uconn.key,
                       key,
                       memory
                     )
                   )
                   |> ExAws.request(),
                 decrypted_obj <-
                   decr_item(
                     obj,
                     uconn.user,
                     uconn.key,
                     key,
                     memory
                   ) do
              # Put the encrypted memory binary in ets.
              Task.Supervisor.async_nolink(Metamorphic.StorjTask, fn ->
                MemoryProcessor.put_ets_memory(
                  "user:#{memory.user_id}-memory:#{memory.id}-key:#{uconn.connection.id}",
                  obj
                )
              end)

              image = decrypted_obj |> Base.encode64()
              path = "data:image/jpg;base64," <> image
              path
            else
              {:error, _rest} ->
                "error"
            end

          is_nil(
            _memory_binary =
                MemoryProcessor.get_ets_memory(
                  "user:#{memory.user_id}-memory:#{memory.id}-key:#{uconn.connection.id}"
                )
          ) &&
            not is_nil(current_user) && current_user.id == memory.user_id ->
            memories_bucket = Encrypted.Session.memories_bucket()

            with {:ok, %{body: obj}} <-
                   ExAws.S3.get_object(
                     memories_bucket,
                     decr_item(
                       memory.memory_url,
                       current_user,
                       uconn.key,
                       key,
                       memory
                     )
                   )
                   |> ExAws.request(),
                 decrypted_obj <-
                   decr_item(
                     obj,
                     current_user,
                     uconn.key,
                     key,
                     memory
                   ) do
              # Put the encrypted memory binary in ets.
              Task.Supervisor.async_nolink(Metamorphic.StorjTask, fn ->
                MemoryProcessor.put_ets_memory(
                  "user:#{memory.user_id}-memory:#{memory.id}-key:#{uconn.connection.id}",
                  obj
                )
              end)

              image = decrypted_obj |> Base.encode64()
              path = "data:image/jpg;base64," <> image
              path
            else
              {:error, _rest} ->
                "error"
            end
        end
    end
  end

  def get_public_user_memory(user, memory, _current_user) do
    cond do
      is_nil(memory) ->
        ""

      is_nil(memory.memory_url) ->
        ""

      not is_nil(
        memory_binary =
            MemoryProcessor.get_ets_memory(
              "profile-user:#{user.id}-memory:#{memory.id}-key:#{user.connection.id}"
            )
      ) ->
        image = decr_public_item(memory_binary, get_memory_key(memory))
        "data:image/jpg;base64," <> image

      is_nil(
        _memory_binary =
            MemoryProcessor.get_ets_memory(
              "profile-user:#{user.id}-memory:#{memory.id}-key:#{user.connection.id}"
            )
      ) ->
        memories_bucket = Encrypted.Session.memories_bucket()
        d_url = decr_public_item(memory.memory_url, get_memory_key(memory))

        with {:ok, %{body: obj}} <-
               ExAws.S3.get_object(
                 memories_bucket,
                 d_url
               )
               |> ExAws.request(),
             decrypted_obj <-
               decr_public_item(
                 obj,
                 get_memory_key(memory)
               ) do
          # Put the encrypted memory binary in ets.
          Task.Supervisor.async_nolink(Metamorphic.StorjTask, fn ->
            MemoryProcessor.put_ets_memory(
              "profile-user:#{user.id}-memory:#{memory.id}-key:#{user.connection.id}",
              obj
            )

            {:ok, :encrypted_profile_memory_put_in_ets}
          end)

          image = decrypted_obj |> Base.encode64()
          path = "data:image/jpg;base64," <> image
          path
        else
          {:error, _rest} ->
            with {:ok, %{body: obj}} <-
                   ExAws.S3.get_object(
                     memories_bucket,
                     d_url
                   )
                   |> ExAws.request(),
                 decrypted_obj <-
                   decr_public_item(
                     obj,
                     get_memory_key(memory)
                   ) do
              # Put the encrypted memory binary in ets.
              Task.Supervisor.async_nolink(Metamorphic.StorjTask, fn ->
                MemoryProcessor.put_ets_memory(
                  "profile-user:#{user.id}-memory:#{memory.id}-key:#{user.connection.id}",
                  obj
                )

                {:ok, :encrypted_profile_memory_put_in_ets}
              end)

              image = decrypted_obj |> Base.encode64()
              path = "data:image/jpg;base64," <> image
              path
            else
              {:error, _rest} ->
                ""
            end
        end
    end
  end

  defp decrypt_memory_binary(memory_binary, uconn, memory, key, current_user) do
    cond do
      is_nil(current_user) ->
        decr_item(
          memory_binary,
          uconn.user,
          uconn.key,
          key
        )
        |> Base.encode64()

      not is_nil(current_user) && memory.user_id != current_user.id ->
        decr_avatar(
          memory_binary,
          uconn.user,
          uconn.key,
          key
        )
        |> Base.encode64()

      not is_nil(current_user) && memory.user_id == current_user.id ->
        decr_avatar(
          memory_binary,
          current_user,
          current_user.conn_key,
          key
        )
        |> Base.encode64()
    end
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
    do: "Gulp! File too large (max 10 MB)."

  def error_to_string(:too_many_files),
    do: "Whoa, too many files."

  def error_to_string(:not_accepted),
    do: "Sorry, that's not an acceptable file type."

  ## CSS styling

  def username_link_text_color(color) do
    case color do
      :brand -> "text-brand-700 hover:text-brand-500"
      :emerald -> "text-emerald-700 hover:text-emerald-500"
      :orange -> "text-orange-700 hover:text-orange-500"
      :pink -> "text-pink-700 hover:text-pink-500"
      :purple -> "text-purple-700 hover:text-purple-500"
      :rose -> "text-rose-700 hover:text-rose-500"
      :yellow -> "text-yellow-700 hover:text-yellow-500"
      :zinc -> "text-zinc-700 hover:text-zinc-500"
      _rest -> "text-brand-700 hover:text-brand-500"
    end
  end

  def username_link_text_color_no_hover(color) do
    case color do
      :brand -> "text-brand-700"
      :emerald -> "text-emerald-700"
      :orange -> "text-orange-700"
      :pink -> "text-pink-700"
      :purple -> "text-purple-700"
      :rose -> "text-rose-700"
      :yellow -> "text-yellow-700"
      :zinc -> "text-zinc-700"
      _rest -> "text-brand-700"
    end
  end

  def badge_color(color) do
    case color do
      :brand -> "bg-brand-50 text-brand-700 ring-brand-600/20"
      :emerald -> "bg-emerald-50 text-emerald-700 ring-emerald-600/20"
      :orange -> "bg-orange-50 text-orange-700 ring-orange-600/20"
      :pink -> "bg-pink-50 text-pink-700 ring-pink-600/20"
      :purple -> "bg-purple-50 text-purple-700 ring-purple-600/20"
      :rose -> "bg-rose-50 text-rose-700 ring-rose-600/20"
      :yellow -> "bg-yellow-50 text-yellow-700 ring-yellow-600/20"
      :zinc -> "bg-zinc-50 text-zinc-700 ring-zinc-600/20"
      _rest -> "bg-brand-50 text-brand-700 ring-brand-600/20"
    end
  end

  def badge_group_hover_color(color) do
    case color do
      :brand -> "group-hover:text-brand-700"
      :emerald -> "group-hover:text-emerald-700"
      :orange -> "group-hover:text-orange-700"
      :pink -> "group-hover:text-pink-700"
      :purple -> "group-hover:text-purple-700"
      :rose -> "group-hover:text-rose-700"
      :yellow -> "group-hover:text-yellow-700"
      :zinc -> "group-hover:text-zinc-700"
      _rest -> "group-hover:text-brand-700"
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
end

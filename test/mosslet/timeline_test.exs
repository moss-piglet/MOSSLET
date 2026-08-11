defmodule Mosslet.TimelineTest do
  use Mosslet.DataCase

  alias Mosslet.Timeline

  describe "posts" do
    alias Mosslet.Timeline.Post

    import Mosslet.TimelineFixtures

    @invalid_attrs %{
      body: nil,
      username: nil,
      favs_count: nil,
      reposts_count: nil,
      user_id: nil
    }
    @valid_password "hello world hello world"
    @valid_username "different_username"
    @valid_email "post@example.com"

    setup do
      user =
        Mosslet.AccountsFixtures.user_fixture(%{
          username: @valid_username,
          password: @valid_password,
          email: @valid_email
        })

      key = get_session_key(user, @valid_password)

      {:ok, user} =
        Mosslet.Accounts.update_user_onboarding_profile(user, %{name: "User One"},
          change_name: true,
          key: key,
          user: user
        )

      reverse_user =
        Mosslet.AccountsFixtures.user_fixture(%{
          username: "reverse_friend",
          email: "reverse_email@example.com",
          password: @valid_password
        })

      r_key = get_session_key(reverse_user, @valid_password)

      # update the visibility
      {:ok, reverse_user} =
        Mosslet.Accounts.update_user_visibility(reverse_user, %{visibility: :connections},
          key: r_key
        )

      {:ok, reverse_user} =
        Mosslet.Accounts.update_user_onboarding_profile(reverse_user, %{name: "User Two"},
          change_name: true,
          key: r_key,
          user: reverse_user
        )

      # We need to create user_connection for the user
      uconn_attrs = %{
        "color" => "rose",
        "temp_label" => "friend",
        "connection_id" => user.connection.id,
        "reverse_user_id" => user.id,
        "selector" => "username",
        "username" => "reverse_friend"
      }

      _user_connection =
        Mosslet.UserConnectionFixtures.user_connection_fixture(uconn_attrs,
          user: user,
          reverse_user: reverse_user,
          key: key,
          r_key: r_key,
          confirm?: true
        )

      %{user: user, reverse_user: reverse_user, key: key}
    end

    test "filter_timeline_posts/2 returns all posts for user", %{
      user: user,
      key: key
    } do
      post_attrs = %{username: @valid_username, username_hash: @valid_username, user_id: user.id}

      post =
        post_fixture(
          post_attrs,
          user: user,
          key: key
        )

      options = %{
        filter: %{user_id: ""}
      }

      [result] = Timeline.filter_timeline_posts(user, options)
      assert result.id == post.id
      assert result.total_reply_count == 0
    end

    test "get_post!/1 returns the post with given id", %{user: user, key: key} do
      post = post_fixture(%{}, user: user, key: key)
      assert Timeline.get_post!(post.id) == post
    end

    test "create_post/1 with valid data creates a post with encrypted data", %{
      user: user,
      key: key
    } do
      valid_attrs = %{
        body: "some body",
        username: "some_username",
        username_hash: "some_username",
        user_id: user.id,
        favs_count: 42,
        reposts_count: 42
      }

      assert {:ok, %Post{} = post} = Timeline.create_post(valid_attrs, user: user, key: key)
      assert post.body != "some body"
      assert post.username != "some_username"
      assert post.username_hash == "some_username"

      assert decrypt_user_item(post.username, user, get_post_key(post, user), key) ==
               "some_username"

      assert decrypt_user_item(post.body, user, get_post_key(post, user), key) ==
               "some body"

      # get post from the db and hash will now be hashed
      post = Timeline.get_post!(post.id)
      assert post.username_hash != "some_username"
      assert post.favs_count == 42
      assert post.reposts_count == 42
    end

    test "create_post/1 with invalid data returns error changeset", %{user: user, key: key} do
      assert {:error, %Ecto.Changeset{}} =
               Timeline.create_post(@invalid_attrs, user: user, key: key)
    end

    test "update_post/2 with valid data updates the post with encrypted data", %{
      user: user,
      key: key
    } do
      post = post_fixture(%{}, user: user, key: key)

      update_attrs = %{
        body: "some updated body",
        username: "some_updated_username",
        favs_count: 43,
        reposts_count: 43
      }

      assert {:ok, %Post{} = post} =
               Timeline.update_post(post, update_attrs, user: user, key: key)

      assert post.body != "some updated body"
      assert post.username != "some_updated_username"
      assert post.favs_count == 43
      assert post.reposts_count == 43

      assert decrypt_user_item(post.body, user, get_post_key(post, user), key) ==
               "some updated body"

      assert decrypt_user_item(post.username, user, get_post_key(post, user), key) ==
               "some_updated_username"
    end

    test "update_post/2 with invalid data returns error changeset", %{user: user, key: key} do
      post = post_fixture(%{}, user: user, key: key)

      assert {:error, %Ecto.Changeset{}} =
               Timeline.update_post(post, @invalid_attrs, user: user, key: key)

      assert post == Timeline.get_post!(post.id)
    end

    test "delete_post/2 requires a user to delete", %{user: user, key: key} do
      post = post_fixture(%{}, user: user, key: key)
      assert {:error, message} = Timeline.delete_post(post)
      assert message == "You do not have permission to delete this post."
      assert {:ok, %Post{}} = Timeline.delete_post(post, user: user)
      assert_raise Ecto.NoResultsError, fn -> Timeline.get_post!(post.id) end
    end

    test "delete_post/2 deletes the post", %{user: user, key: key} do
      post = post_fixture(%{}, user: user, key: key)
      assert {:ok, %Post{}} = Timeline.delete_post(post, user: user)
      assert_raise Ecto.NoResultsError, fn -> Timeline.get_post!(post.id) end
    end

    test "change_post/1 returns a post changeset", %{user: user, key: key} do
      post = post_fixture(%{}, user: user, key: key)
      assert %Ecto.Changeset{} = Timeline.change_post(post)
    end

    test "decrypt_post_favs_list/3 round-trips the encrypted favs_list to plaintext user ids", %{
      user: user,
      key: key
    } do
      post =
        post_fixture(%{visibility: :connections}, user: user, key: key)
        |> Mosslet.Repo.preload([:user_posts])

      # Adding a fav encrypts each user id into the stored favs_list.
      assert {:ok, _post} =
               Timeline.update_post_fav(
                 post,
                 %{favs_list: [user.id], favs_count: 1},
                 user: user,
                 key: key,
                 post_key: Timeline.get_post_sealed_key(post, user)
               )

      stored = Timeline.get_post!(post.id) |> Mosslet.Repo.preload([:user_posts])

      # The raw stored list must NOT contain the plaintext user id (ZK invariant).
      refute user.id in stored.favs_list

      # The shared context helper decrypts it back to the plaintext user id.
      assert Timeline.decrypt_post_favs_list(stored, user, key) == [user.id]

      # Empty / nil lists return [] without attempting decryption.
      assert Timeline.decrypt_post_favs_list(%{stored | favs_list: []}, user, key) == []
      assert Timeline.decrypt_post_favs_list(%{stored | favs_list: nil}, user, key) == []
    end

    test "decrypt_post_reposts_list/3 round-trips the encrypted reposts_list to plaintext user ids",
         %{user: user, key: key} do
      post =
        post_fixture(%{visibility: :connections}, user: user, key: key)
        |> Mosslet.Repo.preload([:user_posts])

      assert {:ok, _post} =
               Timeline.update_post_reposts_list(
                 post,
                 %{reposts_list: [user.id], reposts_count: 1},
                 user: user,
                 key: key,
                 post_key: Timeline.get_post_sealed_key(post, user)
               )

      stored = Timeline.get_post!(post.id) |> Mosslet.Repo.preload([:user_posts])

      refute user.id in stored.reposts_list
      assert Timeline.decrypt_post_reposts_list(stored, user, key) == [user.id]
    end
  end

  defp get_session_key(user, password) do
    case Mosslet.Accounts.User.valid_key_hash?(user, password) do
      {:ok, key} -> key
      {:error, _} -> nil
    end
  end

  defp decrypt_user_item(payload, user, item_key, session_key) do
    Mosslet.Encrypted.Users.Utils.decrypt_user_item(payload, user, item_key, session_key)
  end

  defp get_post_key(post, current_user) do
    cond do
      post.group_id ->
        # there's only one UserPost for group posts
        Enum.at(post.user_posts, 0).key

      post.visibility == :connections || post.visibility == :private ->
        user_post = Timeline.get_user_post(post, current_user)
        user_post.key

      true ->
        # there's only one UserPost for public posts
        Enum.at(post.user_posts, 0).key
    end
  end

  describe "list_public_posts_by_user/2 (personal RSS feed, task #385)" do
    import Mosslet.TimelineFixtures

    @valid_password "hello world hello world"

    setup do
      user =
        Mosslet.AccountsFixtures.user_fixture(%{
          username: "feeduser",
          email: "feeduser@example.com",
          password: @valid_password
        })

      key = get_session_key(user, @valid_password)
      %{user: user, key: key}
    end

    test "returns only the user's public posts, newest first, respecting limit", %{
      user: user,
      key: key
    } do
      # A public post
      public1 =
        post_fixture(%{username: "feeduser", visibility: "public"}, user: user, key: key)

      public2 =
        post_fixture(%{username: "feeduser", visibility: "public"}, user: user, key: key)

      # Non-public posts must be excluded
      _private =
        post_fixture(%{username: "feeduser", visibility: "private"}, user: user, key: key)

      result = Timeline.list_public_posts_by_user(user.id, 25)
      ids = Enum.map(result, & &1.id)

      assert public1.id in ids
      assert public2.id in ids
      assert length(result) == 2
      assert Enum.all?(result, &(&1.visibility == :public))

      # newest first
      [first, second] = result
      assert NaiveDateTime.compare(first.inserted_at, second.inserted_at) in [:gt, :eq]
    end

    test "does not return another user's public posts", %{user: user, key: key} do
      _mine = post_fixture(%{username: "feeduser", visibility: "public"}, user: user, key: key)

      other =
        Mosslet.AccountsFixtures.user_fixture(%{
          username: "otherfeeduser",
          email: "otherfeeduser@example.com",
          password: @valid_password
        })

      other_key = get_session_key(other, @valid_password)

      _theirs =
        post_fixture(%{username: "otherfeeduser", visibility: "public"},
          user: other,
          key: other_key
        )

      result = Timeline.list_public_posts_by_user(user.id, 25)
      assert length(result) == 1
      assert Enum.all?(result, &(&1.user_id == user.id))
    end

    test "respects the limit", %{user: user, key: key} do
      for _ <- 1..3 do
        post_fixture(%{username: "feeduser", visibility: "public"}, user: user, key: key)
      end

      assert length(Timeline.list_public_posts_by_user(user.id, 2)) == 2
    end
  end

  describe "list_unread_replies_for_user/2" do
    import Mosslet.TimelineFixtures

    @valid_password "hello world hello world"

    setup do
      user =
        Mosslet.AccountsFixtures.user_fixture(%{
          username: "replyowner",
          email: "replyowner@example.com",
          password: @valid_password
        })

      key = get_session_key(user, @valid_password)

      {:ok, user} =
        Mosslet.Accounts.update_user_onboarding_profile(user, %{name: "Reply Owner"},
          change_name: true,
          key: key,
          user: user
        )

      replier =
        Mosslet.AccountsFixtures.user_fixture(%{
          username: "replier",
          email: "replier@example.com",
          password: @valid_password
        })

      r_key = get_session_key(replier, @valid_password)

      # The replier must be discoverable by username for the connection request
      {:ok, replier} =
        Mosslet.Accounts.update_user_visibility(replier, %{visibility: :connections}, key: r_key)

      {:ok, replier} =
        Mosslet.Accounts.update_user_onboarding_profile(replier, %{name: "Replier"},
          change_name: true,
          key: r_key,
          user: replier
        )

      uconn_attrs = %{
        "color" => "emerald",
        "temp_label" => "friend",
        "connection_id" => user.connection.id,
        "reverse_user_id" => user.id,
        "selector" => "username",
        "username" => "replier"
      }

      _user_connection =
        Mosslet.UserConnectionFixtures.user_connection_fixture(uconn_attrs,
          user: user,
          reverse_user: replier,
          key: key,
          r_key: r_key,
          confirm?: true
        )

      post = post_fixture(%{username: "replyowner"}, user: user, key: key)

      # Mirror production's create_shared_user_posts (legacy server path): seal
      # the post key for the replier so they hold a UserPost for the post —
      # exactly what the composer does when sharing with connections.
      author_user_post = Timeline.get_user_post(post, user)

      {:ok, raw_post_key} =
        Mosslet.Encrypted.Users.Utils.decrypt_user_attrs_key(
          author_user_post.key,
          user,
          key
        )

      %Mosslet.Timeline.UserPost{}
      |> Mosslet.Timeline.UserPost.sharing_changeset(
        %{key: raw_post_key, post_id: post.id, user_id: replier.id},
        user: replier,
        visibility: "connections"
      )
      |> Repo.insert!()

      %{user: user, key: key, replier: replier, r_key: r_key, post: post}
    end

    test "returns unread replies to the user's own posts, newest first", %{
      user: user,
      replier: replier,
      r_key: r_key,
      post: post
    } do
      reply = reply_to_post(post, replier, r_key, "first reply")

      assert [found] = Timeline.list_unread_replies_for_user(user)
      assert found.id == reply.id
      assert found.post_id == post.id
      assert is_nil(found.parent_reply_id)
      # post: :user_posts is preloaded for sealed-key resolution (ZK)
      assert Ecto.assoc_loaded?(found.post)
      assert Ecto.assoc_loaded?(found.post.user_posts)

      # The replier's own dashboard shows nothing for their own reply
      assert Timeline.list_unread_replies_for_user(replier) == []
    end

    test "includes unread replies to the user's own replies (nested)", %{
      user: user,
      key: key,
      replier: replier,
      r_key: r_key,
      post: post
    } do
      parent = reply_to_post(post, user, key, "owner's own reply")
      nested = reply_to_post(post, replier, r_key, "reply to your reply", parent.id)

      assert [found] = Timeline.list_unread_replies_for_user(user)
      assert found.id == nested.id
      assert found.parent_reply_id == parent.id
    end

    test "excludes already-read replies", %{
      user: user,
      replier: replier,
      r_key: r_key,
      post: post
    } do
      _reply = reply_to_post(post, replier, r_key, "seen it")

      assert [_] = Timeline.list_unread_replies_for_user(user)

      Timeline.mark_replies_read_for_post(post.id, user.id)

      assert Timeline.list_unread_replies_for_user(user) == []
    end

    test "respects the limit across direct and nested replies", %{
      user: user,
      key: key,
      replier: replier,
      r_key: r_key,
      post: post
    } do
      parent = reply_to_post(post, user, key, "owner's own reply")

      for n <- 1..3 do
        reply_to_post(post, replier, r_key, "direct #{n}")
      end

      for n <- 1..3 do
        reply_to_post(post, replier, r_key, "nested #{n}", parent.id)
      end

      result = Timeline.list_unread_replies_for_user(user, %{limit: 4})
      assert length(result) == 4

      # newest first
      assert Enum.chunk_every(result, 2, 1, :discard)
             |> Enum.all?(fn [a, b] ->
               NaiveDateTime.compare(a.inserted_at, b.inserted_at) in [:gt, :eq]
             end)
    end

    defp reply_to_post(post, replier, r_key, body, parent_reply_id \\ nil) do
      user_post = Timeline.get_user_post(post, replier)

      attrs = %{
        "user_id" => replier.id,
        "post_id" => post.id,
        "parent_reply_id" => parent_reply_id,
        "visibility" => "connections",
        "body" => body,
        "username" => "replier"
      }

      {:ok, reply} =
        Timeline.create_reply(attrs,
          user: replier,
          key: r_key,
          post: post,
          post_key: user_post.key,
          visibility: :connections
        )

      reply
    end
  end
end

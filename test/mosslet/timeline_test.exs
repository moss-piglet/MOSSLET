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
end

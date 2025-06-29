defmodule Mosslet.GroupsTest do
  use Mosslet.DataCase

  alias Mosslet.Groups

  describe "groups" do
    alias Mosslet.Groups.Group

    import Mosslet.GroupsFixtures

    @invalid_attrs %{name: nil, description: nil, user_name: nil, user_id: nil, users: []}

    @valid_group_name "some name"
    @valid_password "hello world hello world"
    @valid_username "different_group_username"
    @valid_email "group@example.com"

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
          username: "reverse_group_friend",
          email: "reverse_group_email@example.com",
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
      # the reverse_user id is the user id of the user
      # creating the initial user_connection request
      #
      # the user_id is the recipient_id
      uconn_attrs = %{
        "color" => "rose",
        "temp_label" => "friend",
        "connection_id" => user.connection.id,
        "reverse_user_id" => user.id,
        "selector" => "username",
        "username" => "reverse_group_friend"
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

    test "list_groups/1 returns all groups for user with encrypted data", %{
      user: user,
      reverse_user: reverse_user,
      key: key
    } do
      group_attrs = %{name: @valid_group_name, user_id: user.id, users: [reverse_user]}
      group = group_fixture(group_attrs, user: user, key: key)
      assert Groups.list_groups(user) == [group]
    end

    test "get_group!/1 returns the group with given id and encrypted data", %{
      user: user,
      reverse_user: reverse_user,
      key: key
    } do
      group_attrs = %{name: @valid_group_name, user_id: user.id, users: [reverse_user]}
      group = group_fixture(group_attrs, user: user, key: key)
      assert Groups.get_group!(group.id) == group
    end

    test "create_group/2 with valid data creates a group with encrypted data", %{
      user: user,
      reverse_user: reverse_user,
      key: key
    } do
      valid_attrs = %{
        "name" => "some other name",
        "description" => "some other description",
        "user_id" => user.id,
        "users" => [reverse_user],
        "user_name" => "some other name"
      }

      assert {:ok, %Group{} = group} =
               Groups.create_group(valid_attrs, user: user, key: key, require_password?: false)

      assert group.name != "some other name"
      assert group.description != "some description"

      assert decrypt_item(group.name, user, get_user_group(group, user).key, key) ==
               "some other name"

      assert decrypt_item(group.description, user, get_user_group(group, user).key, key) ==
               "some other description"

      # Ensure the group is created in the database
      db_group = Groups.get_group!(group.id)
      assert Groups.get_group!(group.id) == db_group
    end

    test "create_group/2 with invalid data returns error changeset", %{user: user, key: key} do
      assert {:error, %Ecto.Changeset{}} =
               Groups.create_group(@invalid_attrs, user: user, key: key, require_password?: false)
    end

    test "update_group/2 with valid data updates the group with encrypted data", %{
      user: user,
      reverse_user: reverse_user,
      key: key
    } do
      group_attrs = %{
        "name" => @valid_group_name,
        "description" => "some description",
        "user_id" => user.id,
        "users" => [reverse_user],
        "user_name" => @valid_group_name
      }

      {:ok, group} =
        Groups.create_group(group_attrs, user: user, key: key, require_password?: false)

      group = Groups.get_group!(group.id)

      update_attrs = %{
        "name" => "some updated name",
        "description" => "some updated description",
        "user_id" => user.id,
        "users" => [reverse_user],
        "user_name" => "some updated name",
        "user_connections" => [user.id, reverse_user.id]
      }

      assert {:ok, %Group{} = group} =
               Groups.update_group(group, update_attrs,
                 user: user,
                 key: key,
                 require_password?: false
               )

      assert group.name != "some updated name"
      assert group.description != "some updated description"

      assert decrypt_item(group.name, user, get_user_group(group, user).key, key) ==
               "some updated name"

      assert decrypt_item(group.description, user, get_user_group(group, user).key, key) ==
               "some updated description"
    end

    test "update_group/2 with invalid data returns error changeset", %{
      user: user,
      reverse_user: reverse_user,
      key: key
    } do
      group_attrs = %{name: @valid_group_name, user_id: user.id, users: [reverse_user]}
      group = group_fixture(group_attrs, user: user, key: key)

      assert {:error, %Ecto.Changeset{}} =
               Groups.update_group(group, @invalid_attrs,
                 user: user,
                 key: key,
                 require_password?: false
               )

      assert group == Groups.get_group!(group.id)
    end

    test "delete_group/1 deletes the group", %{user: user, reverse_user: reverse_user, key: key} do
      group_attrs = %{name: @valid_group_name, user_id: user.id, users: [reverse_user]}
      group = group_fixture(group_attrs, user: user, key: key)
      assert {:ok, %Group{}} = Groups.delete_group(group)
      assert_raise Ecto.NoResultsError, fn -> Groups.get_group!(group.id) end
    end

    test "change_group/1 returns a group changeset", %{
      user: user,
      reverse_user: reverse_user,
      key: key
    } do
      group_attrs = %{name: @valid_group_name, user_id: user.id, users: [reverse_user]}
      group = group_fixture(group_attrs, user: user, key: key)
      assert %Ecto.Changeset{} = Groups.change_group(group)
    end
  end

  defp get_session_key(user, password) do
    case Mosslet.Accounts.User.valid_key_hash?(user, password) do
      {:ok, key} -> key
      {:error, _} -> nil
    end
  end

  defp get_user_group(group, user) do
    Mosslet.Groups.get_user_group_for_group_and_user(group, user)
  end

  defp decrypt_item(payload, user, item_key, key) do
    Mosslet.Encrypted.Users.Utils.decrypt_user_item(payload, user, item_key, key)
  end
end

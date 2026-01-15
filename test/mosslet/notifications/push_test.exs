defmodule Mosslet.Notifications.PushTest do
  use Mosslet.DataCase, async: true

  alias Mosslet.Notifications.Push
  alias Mosslet.Notifications.DeviceToken

  describe "register_device_token/2" do
    test "creates a new device token" do
      user = insert(:user)

      attrs = %{
        token: "apns_test_token_123",
        platform: :ios,
        device_name: "iPhone 15",
        app_version: "1.0.0",
        os_version: "17.0"
      }

      assert {:ok, device_token} = Push.register_device_token(user.id, attrs)
      assert device_token.user_id == user.id
      assert device_token.platform == :ios
      assert device_token.device_name == "iPhone 15"
      assert device_token.active == true
    end

    test "updates existing token for same user" do
      user = insert(:user)
      token = "apns_existing_token"

      {:ok, original} =
        Push.register_device_token(user.id, %{
          token: token,
          platform: :ios,
          app_version: "1.0.0"
        })

      {:ok, updated} =
        Push.register_device_token(user.id, %{
          token: token,
          platform: :ios,
          app_version: "2.0.0"
        })

      assert original.id == updated.id
      assert updated.app_version == "2.0.0"
    end

    test "reassigns token to new user if different user registers same token" do
      user1 = insert(:user)
      user2 = insert(:user)
      token = "shared_device_token"

      {:ok, original} =
        Push.register_device_token(user1.id, %{token: token, platform: :android})

      {:ok, reassigned} =
        Push.register_device_token(user2.id, %{token: token, platform: :android})

      assert original.id == reassigned.id
      assert reassigned.user_id == user2.id
    end
  end

  describe "unregister_device_token/1" do
    test "deactivates an existing token" do
      user = insert(:user)
      token = "token_to_deactivate"

      {:ok, _} = Push.register_device_token(user.id, %{token: token, platform: :ios})
      {:ok, deactivated} = Push.unregister_device_token(token)

      assert deactivated.active == false
    end

    test "returns ok for non-existent token" do
      assert {:error, :not_found} = Push.unregister_device_token("nonexistent_token")
    end
  end

  describe "list_user_device_tokens/1" do
    test "returns only active tokens for user" do
      user = insert(:user)

      {:ok, t1} = Push.register_device_token(user.id, %{token: "token1", platform: :ios})
      {:ok, _t2} = Push.register_device_token(user.id, %{token: "token2", platform: :android})
      {:ok, _} = Push.unregister_device_token("token2")

      tokens = Push.list_user_device_tokens(user.id)
      assert length(tokens) == 1
      assert hd(tokens).id == t1.id
    end

    test "returns empty list for user with no tokens" do
      user = insert(:user)
      assert Push.list_user_device_tokens(user.id) == []
    end
  end

  describe "send_notification/3" do
    test "returns empty list when user has no device tokens" do
      user = insert(:user)
      results = Push.send_notification(user.id, :new_post, %{post_id: "123"})
      assert results == []
    end
  end

  describe "delete_all_user_tokens/1" do
    test "removes all tokens for a user" do
      user = insert(:user)

      Push.register_device_token(user.id, %{token: "token1", platform: :ios})
      Push.register_device_token(user.id, %{token: "token2", platform: :android})

      assert {2, _} = Push.delete_all_user_tokens(user.id)
      assert Push.list_user_device_tokens(user.id) == []
    end
  end
end

defmodule MossletWeb.API.DeviceControllerTest do
  use MossletWeb.ConnCase, async: true

  alias Mosslet.Notifications.Push

  setup %{conn: conn} do
    user = insert(:user)
    {:ok, token} = Mosslet.API.Token.generate(user)
    conn = put_req_header(conn, "authorization", "Bearer #{token}")
    {:ok, conn: conn, user: user}
  end

  describe "POST /api/devices/token" do
    test "registers a device token", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/api/devices/token", %{
          "token" => "apns_test_token",
          "platform" => "ios",
          "device_name" => "Test iPhone",
          "app_version" => "1.0.0"
        })

      assert %{"success" => true, "platform" => "ios"} = json_response(conn, 200)

      tokens = Push.list_user_device_tokens(user.id)
      assert length(tokens) == 1
      assert hd(tokens).platform == :ios
    end

    test "registers an android token", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/api/devices/token", %{
          "token" => "fcm_test_token",
          "platform" => "android",
          "device_name" => "Pixel 8",
          "app_version" => "1.0.0"
        })

      assert %{"success" => true, "platform" => "android"} = json_response(conn, 200)

      tokens = Push.list_user_device_tokens(user.id)
      assert length(tokens) == 1
      assert hd(tokens).platform == :android
    end
  end

  describe "DELETE /api/devices/token" do
    test "unregisters a device token", %{conn: conn, user: user} do
      token = "token_to_delete"
      Push.register_device_token(user.id, %{token: token, platform: :ios})

      conn = delete(conn, ~p"/api/devices/token", %{"token" => token})

      assert %{"success" => true} = json_response(conn, 200)

      tokens = Push.list_user_device_tokens(user.id)
      assert tokens == []
    end

    test "returns success for non-existent token", %{conn: conn} do
      conn = delete(conn, ~p"/api/devices/token", %{"token" => "nonexistent"})
      assert %{"success" => true} = json_response(conn, 200)
    end
  end

  describe "GET /api/devices/tokens" do
    test "lists user's device tokens", %{conn: conn, user: user} do
      Push.register_device_token(user.id, %{
        token: "token1",
        platform: :ios,
        device_name: "iPhone"
      })

      Push.register_device_token(user.id, %{
        token: "token2",
        platform: :android,
        device_name: "Pixel"
      })

      conn = get(conn, ~p"/api/devices/tokens")

      assert %{"tokens" => tokens} = json_response(conn, 200)
      assert length(tokens) == 2

      platforms = Enum.map(tokens, & &1["platform"])
      assert :ios in platforms or "ios" in platforms
      assert :android in platforms or "android" in platforms
    end

    test "returns empty list when no tokens", %{conn: conn} do
      conn = get(conn, ~p"/api/devices/tokens")
      assert %{"tokens" => []} = json_response(conn, 200)
    end
  end
end

defmodule MossletWeb.UserHomeLiveTest do
  @moduledoc """
  Characterization tests for `MossletWeb.UserHomeLive` (the user profile page).

  These pin the *server-rendered* structure of the four render variants
  (own / public / connections / no-access) before the Phase 4 view-model +
  components refactor. ZK content (names, profile fields, avatars) is decrypted
  client-side, so we assert on the stable DOM scaffolding the server emits —
  container IDs, ZK hook elements, and `data-*` attributes — rather than on
  decrypted text.

  The auth harness mirrors `MossletWeb.TimelineLiveTest`: a real session key is
  derived from the password, and a billing customer + payment intent satisfy the
  `:subscribed_user` pipeline guarding the profile route.
  """
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures
  import Mosslet.UserConnectionFixtures

  alias Mosslet.Accounts

  @valid_password "hello world hello world!"

  describe "own profile (owner view)" do
    setup [:create_owner]

    test "renders the owner profile scaffolding", %{conn: conn, owner: owner, owner_key: key} do
      {:ok, lv, html} = visit_profile(conn, owner, key, owner.connection.profile.slug)

      assert lv.module == MossletWeb.UserHomeLive
      assert html =~ ~s(id="timeline-container")
      assert has_element?(lv, "#repost-form-handler")
      assert has_element?(lv, "#decrypt-own-profile-fields")
    end

    test "owner identity fields render as ZK decrypt targets", %{
      conn: conn,
      owner: owner,
      owner_key: key
    } do
      {:ok, _lv, html} = visit_profile(conn, owner, key, owner.connection.profile.slug)

      assert html =~ ~s(data-decrypt-field="username")
    end
  end

  describe "public profile (non-owner, :public)" do
    setup [:create_owner, :create_public_profile_user]

    test "renders the public profile via server-side decrypt (no ZK profile hooks)", %{
      conn: conn,
      owner: owner,
      owner_key: key,
      public_user: public_user
    } do
      {:ok, lv, html} = visit_profile(conn, owner, key, public_user.connection.profile.slug)

      assert lv.module == MossletWeb.UserHomeLive
      assert html =~ ~s(id="timeline-container")
      # Public profiles decrypt server-side: neither browser-ZK profile hook present.
      refute has_element?(lv, "#decrypt-own-profile-fields")
      refute has_element?(lv, "#decrypt-conn-profile-fields")
    end
  end

  describe "connections profile (non-owner, :connections, connected)" do
    setup [:create_owner, :create_connections_profile_user, :connect_owner_to_profile_user]

    test "renders the connections profile with the browser-ZK profile hook", %{
      conn: conn,
      owner: owner,
      owner_key: key,
      connections_user: connections_user
    } do
      {:ok, lv, html} = visit_profile(conn, owner, key, connections_user.connection.profile.slug)

      assert lv.module == MossletWeb.UserHomeLive
      assert html =~ ~s(data-profile-scope="conn-profile")
      assert has_element?(lv, "#decrypt-conn-profile-fields")
      refute has_element?(lv, "#decrypt-own-profile-fields")
    end
  end

  describe "private profile (non-owner, :private, not connected)" do
    setup [:create_owner, :create_private_profile_user]

    # The `:maybe_ensure_private_profile` on_mount halts before the LiveView's
    # own `render_no_access/1` branch can run, so the real behavior for a
    # non-owner viewing a private profile is a redirect to "/" (render_no_access
    # is effectively unreachable for this path).
    test "redirects to root with a permission flash", %{
      conn: conn,
      owner: owner,
      owner_key: key,
      private_user: private_user
    } do
      assert {:error, {:redirect, %{to: "/", flash: flash}}} =
               visit_profile(conn, owner, key, private_user.connection.profile.slug)

      assert flash["info"] =~ "You do not have permission to view this page"
    end
  end

  # ---------------------------------------------------------------------------
  # Setup helpers
  # ---------------------------------------------------------------------------

  defp create_owner(_) do
    {user, key, _attrs} = build_subscribed_user("owner", :private)
    %{owner: user, owner_key: key}
  end

  defp create_public_profile_user(_) do
    {user, key, _attrs} = build_subscribed_user("public", :public)
    %{public_user: user, public_user_key: key}
  end

  defp create_connections_profile_user(_) do
    {user, key, attrs} = build_subscribed_user("conn", :connections)
    %{connections_user: user, connections_user_key: key, connections_user_attrs: attrs}
  end

  defp create_private_profile_user(_) do
    {user, key, _attrs} = build_subscribed_user("priv", :private)
    %{private_user: user, private_user_key: key}
  end

  # Creates a confirmed connection so the owner can view the :connections profile.
  defp connect_owner_to_profile_user(%{
         owner: owner,
         owner_key: owner_key,
         connections_user: connections_user,
         connections_user_key: connections_user_key,
         connections_user_attrs: %{username: connections_username}
       }) do
    uconn_attrs = %{
      "color" => "emerald",
      "temp_label" => "friend",
      "connection_id" => owner.connection.id,
      "reverse_user_id" => owner.id,
      "selector" => "username",
      "username" => connections_username
    }

    user_connection =
      user_connection_fixture(uconn_attrs,
        user: owner,
        reverse_user: connections_user,
        key: owner_key,
        r_key: connections_user_key,
        confirm?: true
      )

    %{user_connection: user_connection}
  end

  # Builds a confirmed, onboarded, subscribed user with a created profile at the
  # given visibility. Returns `{user, key, %{username, email}}`.
  defp build_subscribed_user(prefix, visibility) do
    username = "#{prefix}user#{System.unique_integer([:positive])}"
    email = "#{username}@example.com"

    user = user_fixture(%{username: username, email: email, password: @valid_password})
    user = Accounts.confirm_user!(user)
    {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})

    key = get_key(user, @valid_password)

    {:ok, user} =
      Accounts.update_user_onboarding_profile(user, %{name: "#{prefix} user"},
        change_name: true,
        key: key,
        user: user
      )

    {:ok, user} =
      if visibility == :private do
        {:ok, user}
      else
        Accounts.update_user_visibility(user, %{visibility: visibility}, key: key)
      end

    {:ok, customer} = create_billing_customer(user)
    {:ok, _payment_intent} = create_payment_intent(customer)

    user = Accounts.get_user_with_preloads(user.id)

    {:ok, _conn} =
      create_profile(user, key, %{username: username, email: email, visibility: visibility})

    user = Accounts.get_user_with_preloads(user.id)

    {user, key, %{username: username, email: email}}
  end

  # Mirrors edit_profile_live.ex `build_create_params_with_zk/4` + create flow,
  # but with known plaintext (so we don't depend on `user.decrypted`).
  defp create_profile(user, key, %{username: username, email: email, visibility: visibility}) do
    profile_params = %{
      "profile" => %{
        "user_id" => user.id,
        "email" => email,
        "name" => "#{username} name",
        "username" => username,
        "temp_username" => username,
        "avatar_url" => nil,
        "visibility" => to_string(visibility),
        "about" => "",
        "alternate_email" => "",
        "website_url" => "",
        "website_label" => "",
        "banner_image" => "waves",
        "show_avatar?" => "false",
        "show_email?" => "false",
        "show_name?" => "true",
        "opts_map" => %{user: user, key: key, encrypt: true}
      }
    }

    Accounts.create_user_profile(user, profile_params, key: key, user: user, encrypt: true)
  end

  defp create_billing_customer(user) do
    Mosslet.Billing.Customers.create_customer_for_source(
      :user,
      user.id,
      %{
        email: "test@example.com",
        provider: "stripe",
        provider_customer_id: provider_id("cus"),
        user_id: user.id
      }
    )
  end

  defp create_payment_intent(customer) do
    Mosslet.Billing.PaymentIntents.create_payment_intent!(%{
      provider_payment_intent_id: provider_id("pi"),
      provider_customer_id: customer.provider_customer_id,
      provider_latest_charge_id: provider_id("ch"),
      provider_payment_method_id: provider_id("pm"),
      provider_created_at: DateTime.utc_now(),
      amount: 5900,
      amount_received: 5900,
      status: "succeeded",
      billing_customer_id: customer.id
    })
  end

  defp visit_profile(conn, user, key, slug) do
    conn
    |> log_in_user(user, key)
    |> live(~p"/app/profile/#{slug}")
  end

  defp provider_id(prefix),
    do: "#{prefix}_#{Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)}"

  defp get_key(user, password) do
    case Accounts.User.valid_key_hash?(user, password) do
      {:ok, key} -> key
      _ -> raise "Failed to get session key"
    end
  end

  defp log_in_user(conn, user, key) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, Accounts.generate_user_session_token(user))
    |> Plug.Conn.put_session(:key, key)
  end
end

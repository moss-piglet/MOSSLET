defmodule MossletWeb.ConversationLive.GuardianCoreadTest do
  @moduledoc """
  Task #276 — DM co-read: resolve a managed member's ZK org display name for a
  co-reading guardian.

  When a guardian co-reads a managed member's 1:1 DM (I2b), the guardian has NO
  personal UserConnection with the participants, so the connection-keyed partner
  name resolves to "[Unknown]". These tests assert the ZK org-name fallback
  (mirrors timeline #270/#275): the server emits the guardian's sealed `org_key`
  + the managed member's `org_key`-sealed display name as data attributes for the
  `DecryptComposerGuardians` hook, with a neutral "Family member" placeholder.

  A 3rd party (who is personally connected to the managed member) must NOT get
  any org-name data and continues to see the real connection name.
  """
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures
  import Mosslet.UserConnectionFixtures

  alias Mosslet.Accounts
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Conversations
  alias Mosslet.Orgs

  @password "hello world hello world!"

  defp get_key(user) do
    {:ok, key} = Accounts.User.valid_key_hash?(user, @password)
    key
  end

  defp log_in(conn, user, key) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, Accounts.generate_user_session_token(user))
    |> Plug.Conn.put_session(:key, key)
  end

  defp subscribe_user(user) do
    {:ok, customer} =
      Customers.create_customer_for_source(:user, user.id, %{
        email: "billing-#{System.unique_integer([:positive])}@example.com",
        provider: "stripe",
        provider_customer_id: "cus_#{System.unique_integer([:positive])}"
      })

    {:ok, _subscription} =
      Subscriptions.create_subscription(%{
        billing_customer_id: customer.id,
        plan_id: "personal-monthly",
        status: "active",
        quantity: 1,
        provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
        provider_subscription_items: [%{price: "price_test"}],
        current_period_start: NaiveDateTime.utc_now()
      })

    :ok
  end

  defp subscribe_family(org) do
    {:ok, customer} =
      Customers.create_customer_for_source(:org, org.id, %{
        email: "billing-#{System.unique_integer([:positive])}@example.com",
        provider: "stripe",
        provider_customer_id: "cus_#{System.unique_integer([:positive])}"
      })

    {:ok, _sub} =
      Subscriptions.create_subscription(%{
        billing_customer_id: customer.id,
        plan_id: "family-monthly",
        status: "active",
        quantity: 5,
        provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
        provider_subscription_items: [%{price: "price_test"}],
        current_period_start: NaiveDateTime.utc_now()
      })

    :ok
  end

  defp onboarded_user(name_seed) do
    username = "#{name_seed}#{System.unique_integer([:positive])}"
    email = "#{username}@example.com"
    user = user_fixture(%{email: email, username: username, password: @password})
    user = Accounts.confirm_user!(user)
    {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})
    subscribe_user(user)
    key = get_key(user)

    {:ok, user} = Accounts.update_user_visibility(user, %{visibility: :connections}, key: key)

    {:ok, user} =
      Accounts.update_user_onboarding_profile(user, %{name: "Name #{name_seed}"},
        change_name: true,
        key: key,
        user: user
      )

    {user, key, username}
  end

  defp add_member(org, user, role) do
    {:ok, {:ok, membership}} =
      Mosslet.Repo.transaction_on_primary(fn ->
        Orgs.Membership.insert_changeset(org, user, role) |> Mosslet.Repo.insert()
      end)

    membership
  end

  # Creates a confirmed personal UserConnection between `user` and `reverse_user`
  # and returns the requesting user's UserConnection row.
  defp connect(user, key, reverse_user, reverse_username, r_key) do
    uconn_attrs = %{
      "color" => "emerald",
      "temp_label" => "friend",
      "connection_id" => reverse_user.connection.id,
      "reverse_user_id" => reverse_user.id,
      "selector" => "username",
      "username" => reverse_username
    }

    user_connection_fixture(uconn_attrs,
      user: user,
      reverse_user: reverse_user,
      key: key,
      r_key: r_key,
      confirm?: true
    )
  end

  # Builds a co-read DM: a 1:1 between `managed` and `third_party` whose
  # UserConversation is also co-sealed for `guardian` (I2b). The guardian has NO
  # personal connection with either participant.
  defp coread_conversation(managed, managed_key, third_party, tp_username, tp_key, guardian) do
    uconn = connect(managed, managed_key, third_party, tp_username, tp_key)

    {:ok, conversation} =
      Conversations.get_or_create_conversation(uconn.id, [
        %{user_id: managed.id, key: "sealed-conv-key-managed"},
        %{user_id: third_party.id, key: "sealed-conv-key-tp"},
        %{user_id: guardian.id, key: "sealed-conv-key-guardian"}
      ])

    conversation
  end

  describe "guardian co-reading a managed member's DM" do
    setup %{conn: conn} do
      {admin, _admin_key, _a_username} = onboarded_user("admin")
      {:ok, org} = Orgs.create_org(admin, %{"name" => "Smiths", "type" => "family"})
      subscribe_family(org)

      {guardian, guardian_key, _g_username} = onboarded_user("guard")
      {managed, managed_key, _m_username} = onboarded_user("ward")
      {third_party, tp_key, tp_username} = onboarded_user("stranger")

      _g_ms = add_member(org, guardian, :guardian)
      m_ms = add_member(org, managed, :managed_member)

      g_ms = Orgs.get_membership!(guardian, org.slug)
      {:ok, gship} = Orgs.establish_guardianship(g_ms, m_ms)
      {:ok, _active} = Orgs.accept_guardianship(gship)

      # Guardian holds the org_key (sealed copy) and the managed member set an
      # org display name (org_key-sealed ciphertext). Both are required for ZK
      # org-name resolution to return data.
      {:ok, _} =
        Orgs.seal_org_key_for_members(org, [
          %{user_id: guardian.id, sealed_key: "sealed-org-key-guardian"}
        ])

      {:ok, _} = Orgs.set_org_display_name(m_ms, "ciphertext-managed-display-name")

      conversation =
        coread_conversation(managed, managed_key, third_party, tp_username, tp_key, guardian)

      %{
        conn: conn,
        org: org,
        guardian: guardian,
        guardian_key: guardian_key,
        managed: managed,
        managed_key: managed_key,
        third_party: third_party,
        tp_key: tp_key,
        conversation: conversation
      }
    end

    test "guardian sees the managed member's ZK org-name data + placeholder", ctx do
      {:ok, _lv, html} =
        ctx.conn
        |> log_in(ctx.guardian, ctx.guardian_key)
        |> live(~p"/app/conversations/#{ctx.conversation.id}")

      # Neutral placeholder (real name resolves browser-side via the hook).
      assert html =~ "Family member"

      # ZK org-name data is emitted for the DecryptComposerGuardians hook.
      assert html =~ "sealed-org-key-guardian"
      assert html =~ "ciphertext-managed-display-name"

      # The container carries the hook.
      assert html =~ ~s(phx-hook="DecryptComposerGuardians")

      # The guardian must never be told the conversation is with "[Unknown]".
      refute html =~ "[Unknown]"
    end

    test "guardian transparency banner is shown", ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.guardian, ctx.guardian_key)
        |> live(~p"/app/conversations/#{ctx.conversation.id}")

      assert has_element?(lv, "#guardian-coread-banner")
    end

    test "3rd party (connected to managed) sees real name, no org-name data", ctx do
      {:ok, _lv, html} =
        ctx.conn
        |> log_in(ctx.third_party, ctx.tp_key)
        |> live(~p"/app/conversations/#{ctx.conversation.id}")

      # The 3rd party has a personal connection → normal name path, no org fallback.
      refute html =~ "sealed-org-key-guardian"
      refute html =~ "ciphertext-managed-display-name"
    end

    test "guardian's conversation list row resolves the org-name data", ctx do
      {:ok, _lv, html} =
        ctx.conn
        |> log_in(ctx.guardian, ctx.guardian_key)
        |> live(~p"/app/conversations")

      assert html =~ "Family member"
      assert html =~ "sealed-org-key-guardian"
      assert html =~ "ciphertext-managed-display-name"
      assert html =~ ~s(phx-hook="DecryptComposerGuardians")
    end
  end
end

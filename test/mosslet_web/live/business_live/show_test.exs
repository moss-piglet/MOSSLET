defmodule MossletWeb.BusinessLive.ShowTest do
  @moduledoc """
  Business dashboard unread-@mention badge (Task #280).

  The per-circle badge mirrors the proven personal circles index: the count is
  server-authoritative and ZK-safe (derived from `GroupMessageMention` records —
  UUIDs the server already holds — never ciphertext), and refreshes live when a
  new message lands in any business circle the viewer belongs to.
  """
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.GroupMessages
  alias Mosslet.Groups
  alias Mosslet.Orgs

  @password "hello world hello world!"

  defp get_key(user) do
    {:ok, key} = Accounts.User.valid_key_hash?(user, @password)
    key
  end

  defp to_letters(digits) do
    digits
    |> String.graphemes()
    |> Enum.map_join(fn d -> <<?a + String.to_integer(d)>> end)
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

  defp subscribe_org(org) do
    customer =
      case Customers.get_customer_by_source(:org, org.id) do
        nil ->
          {:ok, customer} =
            Customers.create_customer_for_source(:org, org.id, %{
              email: "billing-#{System.unique_integer([:positive])}@example.com",
              provider: "stripe",
              provider_customer_id: "cus_#{System.unique_integer([:positive])}"
            })

          customer

        customer ->
          customer
      end

    {:ok, _sub} =
      Subscriptions.create_subscription(%{
        billing_customer_id: customer.id,
        plan_id: "business-monthly",
        status: "active",
        quantity: 5,
        provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
        provider_subscription_items: [%{price: "price_test"}],
        current_period_start: NaiveDateTime.utc_now()
      })

    :ok
  end

  defp onboarded_user(name_seed) do
    email = "#{name_seed}#{System.unique_integer([:positive])}@example.com"
    username = "#{name_seed}#{System.unique_integer([:positive])}"
    user = user_fixture(%{email: email, username: username, password: @password})
    user = Accounts.confirm_user!(user)
    {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})
    subscribe_user(user)
    key = get_key(user)

    name =
      "Person " <> (System.unique_integer([:positive]) |> Integer.to_string() |> to_letters())

    {:ok, user} =
      Accounts.update_user_onboarding_profile(user, %{name: name},
        change_name: true,
        key: key,
        user: user
      )

    {user, key}
  end

  defp add_member(org, user, role) do
    {:ok, {:ok, membership}} =
      Mosslet.Repo.transaction_on_primary(fn ->
        Orgs.Membership.insert_changeset(org, user, role) |> Mosslet.Repo.insert()
      end)

    membership
  end

  defp zk_attrs do
    %{
      encrypted_name: "encrypted-name-blob",
      encrypted_description: "encrypted-desc-blob",
      name_blind_index: "circle name #{System.unique_integer([:positive])}",
      sealed_creator_key: "sealed-creator-key-blob",
      encrypted_user_name: "encrypted-owner-name",
      encrypted_owner_moniker: "encrypted-owner-moniker",
      encrypted_owner_avatar_img: "encrypted-owner-avatar",
      require_password?: false,
      password: ""
    }
  end

  defp sealed_for(user) do
    %{
      "user_id" => user.id,
      "sealed_key" => "sealed-#{user.id}",
      "encrypted_name" => "name-#{user.id}",
      "encrypted_moniker" => "moniker-#{user.id}",
      "encrypted_avatar_img" => "avatar-#{user.id}"
    }
  end

  defp confirm_membership(group, user) do
    ug = Enum.find(Groups.get_group!(group.id).user_groups, &(&1.user_id == user.id))

    {:ok, {:ok, _}} =
      Mosslet.Repo.transaction_on_primary(fn ->
        ug |> Groups.UserGroup.confirm_changeset() |> Mosslet.Repo.update()
      end)

    :ok
  end

  # Build a message sent by `sender` that mentions `mentioned` (so it is NOT a
  # self-mention) and persist the mention record. Returns the message for use in
  # realtime broadcasts.
  defp mention(group, sender, mentioned) do
    group = Groups.get_group!(group.id)
    sender_ug = Enum.find(group.user_groups, &(&1.user_id == sender.id))
    mentioned_ug = Enum.find(group.user_groups, &(&1.user_id == mentioned.id))

    {:ok, message} =
      GroupMessages.create_message(
        %{content: "ciphertext", group_id: group.id, sender_id: sender_ug.id},
        encrypted_content: "ciphertext"
      )

    {:ok, _} = GroupMessages.create_mentions_for_message(message, [mentioned_ug.id])
    message
  end

  setup %{conn: conn} do
    {admin, admin_key} = onboarded_user("bdadmin")
    {:ok, org} = Orgs.create_org(admin, %{"name" => "BizDashCo", "type" => "business"})
    :ok = subscribe_org(org)

    {member, member_key} = onboarded_user("bdmember")
    add_member(org, member, :member)

    {:ok, group} =
      Groups.create_business_circle_zk(org, admin, zk_attrs(), [member], [sealed_for(member)])

    confirm_membership(group, member)

    %{
      conn: conn,
      org: org,
      group: group,
      admin: admin,
      admin_key: admin_key,
      member: member,
      member_key: member_key
    }
  end

  describe "unread @mention badge (Task #280)" do
    test "no badge renders when the viewer has no unread mentions", ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#circle-#{ctx.group.id}")
      refute has_element?(lv, "#circle-#{ctx.group.id}-mentions")
    end

    test "an indigo badge with the unread count renders when the viewer is mentioned", ctx do
      mention(ctx.group, ctx.member, ctx.admin)

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#circle-#{ctx.group.id}-mentions", "1")
    end

    test "overflow counts render as 9+", ctx do
      for _ <- 1..10, do: mention(ctx.group, ctx.member, ctx.admin)

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#circle-#{ctx.group.id}-mentions", "9+")
    end

    test "the badge appears live on a new_message broadcast", ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}")

      refute has_element?(lv, "#circle-#{ctx.group.id}-mentions")

      message = mention(ctx.group, ctx.member, ctx.admin)

      Phoenix.PubSub.broadcast(Mosslet.PubSub, "group:#{ctx.group.id}", %{
        event: "new_message",
        payload: %{message: message}
      })

      assert render(lv) =~ "circle-#{ctx.group.id}-mentions"
      assert has_element?(lv, "#circle-#{ctx.group.id}-mentions", "1")
    end
  end
end

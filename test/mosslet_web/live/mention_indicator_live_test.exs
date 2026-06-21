defmodule MossletWeb.MentionIndicatorLiveTest do
  @moduledoc """
  Business-only global unread-@mention indicator (Task #281).

  The indicator is a sticky, page-independent LiveView that shows the AGGREGATE
  count of unread `@mentions` across every business circle the viewer belongs to.
  The count is server-authoritative and ZK-safe (summed from
  `GroupMessageMention` records — UUIDs the server already holds — never
  ciphertext), and it both appears and clears live without a reload. It is
  deliberately scoped to Business: family/personal users never see it.
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

  # Build a message sent by `sender` that mentions `mentioned` (not a
  # self-mention) and persist the mention record. Returns the message.
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

  defp mount_indicator(conn, user, key) do
    conn
    |> log_in(user, key)
    |> live_isolated(MossletWeb.MentionIndicatorLive,
      session: %{"user_id" => user.id}
    )
  end

  setup %{conn: conn} do
    {admin, admin_key} = onboarded_user("miadmin")
    {:ok, org} = Orgs.create_org(admin, %{"name" => "MentionBizCo", "type" => "business"})
    :ok = subscribe_org(org)

    {member, member_key} = onboarded_user("mimember")
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

  describe "business unread-@mention indicator (Task #281)" do
    test "no indicator renders when the viewer has no unread mentions", ctx do
      {:ok, view, _html} = mount_indicator(ctx.conn, ctx.admin, ctx.admin_key)

      refute has_element?(view, "#mention-indicator")
    end

    test "an indigo aggregate pill with the unread count renders when mentioned", ctx do
      mention(ctx.group, ctx.member, ctx.admin)

      {:ok, view, _html} = mount_indicator(ctx.conn, ctx.admin, ctx.admin_key)

      assert has_element?(view, "#mention-indicator")
      assert has_element?(view, "#mention-indicator-count", "1")
    end

    test "with a single circle, the pill links straight to that circle's chat", ctx do
      mention(ctx.group, ctx.member, ctx.admin)

      {:ok, view, _html} = mount_indicator(ctx.conn, ctx.admin, ctx.admin_key)

      path = ~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}"
      assert has_element?(view, ~s|a#mention-indicator[href="#{path}"]|)
      # No popover for the single-circle case.
      refute has_element?(view, "#mention-indicator-panel")
    end

    test "with several circles, the pill spins open per-circle direct links", ctx do
      {:ok, group2} =
        Groups.create_business_circle_zk(
          ctx.org,
          ctx.admin,
          zk_attrs(),
          [ctx.member],
          [sealed_for(ctx.member)]
        )

      confirm_membership(group2, ctx.member)

      mention(ctx.group, ctx.member, ctx.admin)
      mention(group2, ctx.member, ctx.admin)

      {:ok, view, _html} = mount_indicator(ctx.conn, ctx.admin, ctx.admin_key)

      # The pill is now a popover toggle (button), and the panel links to each
      # circle's chat directly.
      assert has_element?(view, "button#mention-indicator")
      assert has_element?(view, "#mention-indicator-panel")

      path1 = ~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}"
      path2 = ~p"/app/business/#{ctx.org.slug}/circles/#{group2.id}"
      assert has_element?(view, ~s|#mention-indicator-panel a[href="#{path1}"]|)
      assert has_element?(view, ~s|#mention-indicator-panel a[href="#{path2}"]|)
    end

    test "overflow counts render as 9+", ctx do
      for _ <- 1..10, do: mention(ctx.group, ctx.member, ctx.admin)

      {:ok, view, _html} = mount_indicator(ctx.conn, ctx.admin, ctx.admin_key)

      assert has_element?(view, "#mention-indicator-count", "9+")
    end

    test "the indicator appears live on a new_message broadcast", ctx do
      {:ok, view, _html} = mount_indicator(ctx.conn, ctx.admin, ctx.admin_key)

      refute has_element?(view, "#mention-indicator")

      message = mention(ctx.group, ctx.member, ctx.admin)

      Phoenix.PubSub.broadcast(Mosslet.PubSub, "group:#{ctx.group.id}", %{
        event: "new_message",
        payload: %{message: message}
      })

      assert has_element?(view, "#mention-indicator-count", "1")
    end

    test "the indicator clears live when the viewer reads the circle", ctx do
      mention(ctx.group, ctx.member, ctx.admin)

      {:ok, view, _html} = mount_indicator(ctx.conn, ctx.admin, ctx.admin_key)

      assert has_element?(view, "#mention-indicator-count", "1")

      # Reading the circle marks mentions read and broadcasts `mentions_read`,
      # which the sticky indicator recomputes on (it never remounts on its own).
      admin_ug =
        Groups.get_group!(ctx.group.id).user_groups
        |> Enum.find(&(&1.user_id == ctx.admin.id))

      GroupMessages.mark_mentions_as_read(admin_ug.id, ctx.group.id)

      refute has_element?(view, "#mention-indicator")
    end

    test "personal-only users never see the indicator (business-only scope)", ctx do
      {personal, personal_key} = onboarded_user("mipersonal")

      {:ok, view, _html} = mount_indicator(ctx.conn, personal, personal_key)

      refute has_element?(view, "#mention-indicator")
    end
  end
end

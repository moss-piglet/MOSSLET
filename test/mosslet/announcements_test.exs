defmodule Mosslet.AnnouncementsTest do
  use Mosslet.DataCase, async: false

  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Announcements
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Groups

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

  defp onboarded_user(name_seed) do
    email = "#{name_seed}#{System.unique_integer([:positive])}@example.com"
    user = user_fixture(%{email: email, password: @password})
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
        Mosslet.Orgs.Membership.insert_changeset(org, user, role) |> Mosslet.Repo.insert()
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
        ug |> Mosslet.Groups.UserGroup.confirm_changeset() |> Mosslet.Repo.update()
      end)

    :ok
  end

  defp set_circle_role(group, user, role) do
    ug = Enum.find(Groups.get_group!(group.id).user_groups, &(&1.user_id == user.id))

    {:ok, {:ok, _}} =
      Mosslet.Repo.transaction_on_primary(fn ->
        ug |> Ecto.Changeset.change(role: role) |> Mosslet.Repo.update()
      end)

    :ok
  end

  defp announcement_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        "encrypted_title" => "encrypted-title-blob",
        "encrypted_body" => "encrypted-body-blob",
        "priority" => :normal,
        "expires_at" => nil
      },
      overrides
    )
  end

  setup do
    {owner, _ak} = onboarded_user("annowner")
    {:ok, org} = Mosslet.Orgs.create_org(owner, %{"name" => "Anncorp", "type" => "business"})

    {admin, _adk} = onboarded_user("annadmin")
    add_member(org, admin, :admin)

    {member, _mk} = onboarded_user("annmember")
    add_member(org, member, :member)

    {outsider, _ok} = onboarded_user("annoutsider")

    {:ok, group} =
      Groups.create_business_circle_zk(org, owner, zk_attrs(), [member], [sealed_for(member)])

    confirm_membership(group, member)

    %{org: org, group: group, owner: owner, admin: admin, member: member, outsider: outsider}
  end

  describe "org tier authority (I1)" do
    test "org owner can post an org-wide announcement, stamping org_id + author_id", ctx do
      assert {:ok, ann} =
               Announcements.create_org_announcement(ctx.org, ctx.owner, announcement_attrs())

      assert ann.org_id == ctx.org.id
      assert is_nil(ann.group_id)
      assert ann.author_id == ctx.owner.id
      assert ann.priority == :normal
    end

    test "org admin can post an org-wide announcement", ctx do
      assert {:ok, _ann} =
               Announcements.create_org_announcement(ctx.org, ctx.admin, announcement_attrs())
    end

    test "a plain org member cannot post an org-wide announcement", ctx do
      assert {:error, :unauthorized} =
               Announcements.create_org_announcement(ctx.org, ctx.member, announcement_attrs())
    end

    test "a non-member cannot post an org-wide announcement", ctx do
      assert {:error, :unauthorized} =
               Announcements.create_org_announcement(ctx.org, ctx.outsider, announcement_attrs())
    end

    test "can_post_org_announcement?/2 reflects owner/admin only", ctx do
      assert Announcements.can_post_org_announcement?(ctx.org, ctx.owner.id)
      assert Announcements.can_post_org_announcement?(ctx.org, ctx.admin.id)
      refute Announcements.can_post_org_announcement?(ctx.org, ctx.member.id)
      refute Announcements.can_post_org_announcement?(ctx.org, ctx.outsider.id)
    end
  end

  describe "circle tier authority (I1 — team lead = circle owner/admin/moderator)" do
    test "the circle owner can post a circle announcement, stamping group_id", ctx do
      assert {:ok, ann} =
               Announcements.create_circle_announcement(
                 ctx.group,
                 ctx.owner,
                 announcement_attrs()
               )

      assert ann.group_id == ctx.group.id
      assert is_nil(ann.org_id)
      assert ann.author_id == ctx.owner.id
    end

    test "a plain circle member cannot post a circle announcement", ctx do
      assert {:error, :unauthorized} =
               Announcements.create_circle_announcement(
                 ctx.group,
                 ctx.member,
                 announcement_attrs()
               )
    end

    test "a circle moderator (team lead) can post a circle announcement", ctx do
      set_circle_role(ctx.group, ctx.member, :moderator)
      group = Groups.get_group!(ctx.group.id)

      assert {:ok, _ann} =
               Announcements.create_circle_announcement(group, ctx.member, announcement_attrs())
    end

    test "a circle admin can post a circle announcement", ctx do
      set_circle_role(ctx.group, ctx.member, :admin)
      group = Groups.get_group!(ctx.group.id)

      assert {:ok, _ann} =
               Announcements.create_circle_announcement(group, ctx.member, announcement_attrs())
    end

    test "an org admin who is NOT in the circle cannot post to it", ctx do
      # The admin was never added to the circle -> holds no managing UserGroup.
      assert {:error, :unauthorized} =
               Announcements.create_circle_announcement(
                 ctx.group,
                 ctx.admin,
                 announcement_attrs()
               )
    end
  end

  describe "scoping (org XOR group)" do
    test "list_org_announcements/1 returns only this org's announcements", ctx do
      {:ok, _org_ann} =
        Announcements.create_org_announcement(ctx.org, ctx.owner, announcement_attrs())

      {:ok, _circle_ann} =
        Announcements.create_circle_announcement(ctx.group, ctx.owner, announcement_attrs())

      org_list = Announcements.list_org_announcements(ctx.org)
      assert length(org_list) == 1
      assert Enum.all?(org_list, &(&1.org_id == ctx.org.id))
      assert Enum.all?(org_list, &is_nil(&1.group_id))
    end

    test "list_circle_announcements/1 returns only this circle's announcements", ctx do
      {:ok, _org_ann} =
        Announcements.create_org_announcement(ctx.org, ctx.owner, announcement_attrs())

      {:ok, _circle_ann} =
        Announcements.create_circle_announcement(ctx.group, ctx.owner, announcement_attrs())

      circle_list = Announcements.list_circle_announcements(ctx.group)
      assert length(circle_list) == 1
      assert Enum.all?(circle_list, &(&1.group_id == ctx.group.id))
      assert Enum.all?(circle_list, &is_nil(&1.org_id))
    end
  end

  describe "listing: pinned first, expiry, partition" do
    test "pinned announcements sort first; partition_pinned/1 pulls one banner", ctx do
      {:ok, _normal} =
        Announcements.create_org_announcement(ctx.org, ctx.owner, announcement_attrs())

      {:ok, pinned} =
        Announcements.create_org_announcement(
          ctx.org,
          ctx.owner,
          announcement_attrs(%{"priority" => :pinned})
        )

      list = Announcements.list_org_announcements(ctx.org)
      assert hd(list).id == pinned.id

      {banner, recent} = Announcements.partition_pinned(list)
      assert banner.id == pinned.id
      assert length(recent) == 1
    end

    test "partition_pinned/1 returns nil banner when nothing is pinned", ctx do
      {:ok, _a} = Announcements.create_org_announcement(ctx.org, ctx.owner, announcement_attrs())

      {banner, recent} =
        ctx.org |> Announcements.list_org_announcements() |> Announcements.partition_pinned()

      assert is_nil(banner)
      assert length(recent) == 1
    end

    test "expired announcements drop out of the listing", ctx do
      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      {:ok, _expired} =
        Announcements.create_org_announcement(
          ctx.org,
          ctx.owner,
          announcement_attrs(%{"expires_at" => past})
        )

      assert Announcements.list_org_announcements(ctx.org) == []
    end
  end

  describe "read receipts + unread counts (ZK-safe)" do
    test "mark_read/2 is idempotent and clears the unread count", ctx do
      {:ok, ann} = Announcements.create_org_announcement(ctx.org, ctx.owner, announcement_attrs())

      assert Announcements.unread_org_count(ctx.org, ctx.member) == 1

      :ok = Announcements.mark_read(ann, ctx.member)
      :ok = Announcements.mark_read(ann, ctx.member)

      assert Announcements.unread_org_count(ctx.org, ctx.member) == 0
    end

    test "mark_all_read_org/2 clears all unread for the user", ctx do
      {:ok, _a} = Announcements.create_org_announcement(ctx.org, ctx.owner, announcement_attrs())
      {:ok, _b} = Announcements.create_org_announcement(ctx.org, ctx.owner, announcement_attrs())

      assert Announcements.unread_org_count(ctx.org, ctx.member) == 2
      :ok = Announcements.mark_all_read_org(ctx.org, ctx.member)
      assert Announcements.unread_org_count(ctx.org, ctx.member) == 0
    end
  end

  describe "parse_expires_at/1 (timezone-correct auto-hide)" do
    test "parses a UTC ISO8601 string (with Z) the browser sends from local time" do
      assert %DateTime{} = dt = Announcements.parse_expires_at("2026-06-18T22:10:00.000Z")
      assert DateTime.to_iso8601(dt) == "2026-06-18T22:10:00Z"
    end

    test "parses an offset ISO8601 string into the correct UTC instant" do
      # 18:10 at +02:00 is 16:10 UTC.
      dt = Announcements.parse_expires_at("2026-06-18T18:10:00+02:00")
      assert dt.hour == 16
      assert dt.minute == 10
      assert dt.time_zone == "Etc/UTC"
    end

    test "treats a bare offset-less value (no-JS fallback) as UTC" do
      dt = Announcements.parse_expires_at("2026-06-18T15:30")
      assert dt.hour == 15
      assert dt.minute == 30
      assert dt.time_zone == "Etc/UTC"
    end

    test "returns nil for blank or unparseable values" do
      assert is_nil(Announcements.parse_expires_at(""))
      assert is_nil(Announcements.parse_expires_at("   "))
      assert is_nil(Announcements.parse_expires_at("not-a-date"))
      assert is_nil(Announcements.parse_expires_at(nil))
    end
  end

  describe "edit/delete authority" do
    test "the author can delete their own announcement", ctx do
      {:ok, ann} = Announcements.create_org_announcement(ctx.org, ctx.owner, announcement_attrs())
      assert {:ok, :deleted} = Announcements.delete_announcement(ann, ctx.owner)
      assert Announcements.list_org_announcements(ctx.org) == []
    end

    test "an org admin can delete another author's org announcement", ctx do
      {:ok, ann} = Announcements.create_org_announcement(ctx.org, ctx.owner, announcement_attrs())
      assert {:ok, :deleted} = Announcements.delete_announcement(ann, ctx.admin)
    end

    test "a plain member cannot delete an org announcement", ctx do
      {:ok, ann} = Announcements.create_org_announcement(ctx.org, ctx.owner, announcement_attrs())
      assert {:error, :unauthorized} = Announcements.delete_announcement(ann, ctx.member)
    end
  end
end

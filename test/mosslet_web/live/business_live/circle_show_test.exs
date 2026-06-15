defmodule MossletWeb.BusinessLive.CircleShowTest do
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Files
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

  defp file_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        "storage_path" => "uploads/files/#{Ecto.UUID.generate()}.bin",
        "encrypted_filename" => "encrypted-filename-blob",
        "checksum" => "sha256-checksum-blob",
        "size_bytes" => 2048
      },
      overrides
    )
  end

  setup %{conn: conn} do
    {admin, admin_key} = onboarded_user("csadmin")
    {:ok, org} = Orgs.create_org(admin, %{"name" => "CircleShowCo", "type" => "business"})

    {member, member_key} = onboarded_user("csmember")
    add_member(org, member, :member)

    {outsider, outsider_key} = onboarded_user("csoutsider")

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
      member_key: member_key,
      outsider: outsider,
      outsider_key: outsider_key
    }
  end

  describe "mount auth + eligibility" do
    test "a confirmed circle member can view the circle", ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      assert has_element?(lv, "#shared-files-panel")
      assert has_element?(lv, "#circle-members-roster")
      assert has_element?(lv, "#circle-chat-panel")
    end

    test "redirects a non-member of the org to the business dashboard", ctx do
      assert {:error, {:live_redirect, %{to: to}}} =
               ctx.conn
               |> log_in(ctx.outsider, ctx.outsider_key)
               |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      assert to == "/app/business"
    end

    test "redirects when the circle is not in this org", ctx do
      # A different business org owned by the outsider.
      {:ok, other_org} =
        Orgs.create_org(ctx.outsider, %{"name" => "Otherco", "type" => "business"})

      assert {:error, {:live_redirect, %{to: to}}} =
               ctx.conn
               |> log_in(ctx.admin, ctx.admin_key)
               |> live(~p"/app/business/#{other_org.slug}/circles/#{ctx.group.id}")

      # The admin isn't a member of other_org, so the membership-scoped org
      # lookup sends them back to the business index.
      assert to == "/app/business"
    end

    test "redirects a family org away (business only)", ctx do
      {:ok, family} = Orgs.create_org(ctx.admin, %{"name" => "Fam", "type" => "family"})

      assert {:error, {:live_redirect, %{to: "/app/business"}}} =
               ctx.conn
               |> log_in(ctx.admin, ctx.admin_key)
               |> live(~p"/app/business/#{family.slug}/circles/#{ctx.group.id}")
    end
  end

  describe "Files panel" do
    test "renders shared files the viewer can read with delete affordance", ctx do
      {:ok, file} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())

      {:ok, _} =
        Files.finalize_shared_file_zk(file, [
          %{"user_id" => ctx.admin.id, "sealed_key" => "sealed-admin"}
        ])

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      assert has_element?(lv, "#shared-file-#{file.id}")
      # The uploader (admin) sees a remove button.
      assert has_element?(lv, "#delete-#{file.id}")
      assert has_element?(lv, "#download-#{file.id}")
    end

    test "a non-uploader, non-admin member does not get a delete button", ctx do
      {:ok, file} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())

      {:ok, _} =
        Files.finalize_shared_file_zk(file, [
          %{"user_id" => ctx.member.id, "sealed_key" => "sealed-member"}
        ])

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.member, ctx.member_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      assert has_element?(lv, "#shared-file-#{file.id}")
      refute has_element?(lv, "#delete-#{file.id}")
    end

    test "delete_shared_file removes the file for an authorized uploader", ctx do
      {:ok, file} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())

      {:ok, _} =
        Files.finalize_shared_file_zk(file, [
          %{"user_id" => ctx.admin.id, "sealed_key" => "sealed-admin"}
        ])

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      lv |> element("#delete-#{file.id}") |> render_click()

      refute has_element?(lv, "#shared-file-#{file.id}")
      assert is_nil(Files.get_shared_file(file.id))
    end

    test "a member cannot delete another's file via the delete event", ctx do
      {:ok, file} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())

      {:ok, _} =
        Files.finalize_shared_file_zk(file, [
          %{"user_id" => ctx.member.id, "sealed_key" => "sealed-member"}
        ])

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.member, ctx.member_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      # The member has no delete button, but a tampered client could still push
      # the event — the server must refuse and keep the record.
      render_hook(lv, "delete_shared_file", %{"id" => file.id})
      refute is_nil(Files.get_shared_file(file.id))
    end
  end

  describe "transparency surface (I4)" do
    test "always renders the honest who-can-read copy", ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      assert render(lv) =~ "Who can open these files"
      assert render(lv) =~ "recall copies already downloaded"
    end
  end

  describe "members roster scoping" do
    test "shows only circle members, not all org members", ctx do
      # A third org member who has NOT been added to this circle.
      {nonmember, _key} = onboarded_user("csnonmember")
      add_member(ctx.org, nonmember, :member)

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      # The circle's actual members (admin owner + confirmed member) appear.
      assert has_element?(lv, "#circle-member-#{ctx.admin.id}")
      assert has_element?(lv, "#circle-member-#{ctx.member.id}")

      # The org member who isn't in the circle must NOT appear in the roster.
      refute has_element?(lv, "#circle-member-#{nonmember.id}")
    end
  end

  describe "add members (ZK write path)" do
    test "owner sees the add-members affordance for any org member not yet in the circle",
         ctx do
      # An org member NOT in the circle — and with NO personal connection to the
      # admin. Org membership alone must make them addable.
      {orgmate, _key} = onboarded_user("csorgmate")
      add_member(ctx.org, orgmate, :member)

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      assert has_element?(lv, "#show-add-members-button")
      refute has_element?(lv, "#circle-member-#{orgmate.id}")

      lv |> element("#show-add-members-button") |> render_click()
      assert has_element?(lv, "#add-member-#{orgmate.id}")
    end

    test "an outsider (not in the org) is never addable", ctx do
      # An org member to ensure the add-members affordance shows at all.
      {orgmate, _key} = onboarded_user("csorgmate0")
      add_member(ctx.org, orgmate, :member)

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      lv |> element("#show-add-members-button") |> render_click()
      assert has_element?(lv, "#add-member-#{orgmate.id}")
      refute has_element?(lv, "#add-member-#{ctx.outsider.id}")

      # A tampered client requesting an outsider must be refused server-side (I1).
      render_hook(lv, "request_add_members", %{"user_ids" => [ctx.outsider.id]})

      render_hook(lv, "finalize_group_members_zk", %{
        "sealed_members" => [sealed_for(ctx.outsider)]
      })

      group = Groups.get_group!(ctx.group.id)
      refute Enum.any?(group.user_groups, &(&1.user_id == ctx.outsider.id))
    end

    test "request_add_members refuses a non-manager (member) even if tampered", ctx do
      {orgmate, _key} = onboarded_user("csorgmate2")
      add_member(ctx.org, orgmate, :member)

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.member, ctx.member_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      # A plain member has no add-members affordance.
      refute has_element?(lv, "#show-add-members-button")

      # A tampered client pushing the event must be refused server-side.
      render_hook(lv, "request_add_members", %{"user_ids" => [orgmate.id]})

      group = Groups.get_group!(ctx.group.id)
      refute Enum.any?(group.user_groups, &(&1.user_id == orgmate.id))
    end

    test "finalize_group_members_zk adds an eligible org member to the circle (no connection needed)",
         ctx do
      {orgmate, _key} = onboarded_user("csorgmate3")
      add_member(ctx.org, orgmate, :member)

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      render_hook(lv, "finalize_group_members_zk", %{
        "sealed_members" => [sealed_for(orgmate)]
      })

      group = Groups.get_group!(ctx.group.id)
      assert Enum.any?(group.user_groups, &(&1.user_id == orgmate.id))
    end
  end

  describe "leave circle (self)" do
    test "a non-owner member can leave and is bounced to the org dashboard", ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.member, ctx.member_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      assert has_element?(lv, "#leave-circle-button")

      assert {:error, {:live_redirect, %{to: to}}} =
               lv |> element("#leave-circle-button") |> render_click()

      assert to == "/app/business/#{ctx.org.slug}"

      group = Groups.get_group!(ctx.group.id)
      refute Enum.any?(group.user_groups, &(&1.user_id == ctx.member.id))
    end

    test "leaving revokes the member's sealed file access (re-add needs catch-up — Task #234)",
         ctx do
      {:ok, file} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())

      {:ok, _} =
        Files.finalize_shared_file_zk(file, [
          %{"user_id" => ctx.admin.id, "sealed_key" => "sealed-#{ctx.admin.id}"},
          %{"user_id" => ctx.member.id, "sealed_key" => "sealed-#{ctx.member.id}"}
        ])

      # The member can read the file before leaving.
      refute is_nil(Files.get_user_shared_file(file, ctx.member))

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.member, ctx.member_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      assert {:error, {:live_redirect, _}} =
               lv |> element("#leave-circle-button") |> render_click()

      # Sealed file access is gone: a re-add must explicitly catch them up again.
      assert is_nil(Files.get_user_shared_file(file, ctx.member))
      assert {:error, :unauthorized} = Files.presigned_download_url(file, ctx.member)
    end

    test "the circle owner has no leave affordance and a tampered leave is refused", ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      refute has_element?(lv, "#leave-circle-button")

      # A tampered client pushing the event must be refused — the owner stays.
      render_hook(lv, "leave_circle", %{})

      group = Groups.get_group!(ctx.group.id)
      assert Enum.any?(group.user_groups, &(&1.user_id == ctx.admin.id))
    end
  end

  describe "remove member (owner/admin)" do
    test "the circle owner sees a Remove affordance and can remove a member", ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      assert has_element?(lv, "#remove-member-#{ctx.member.id}")

      lv |> element("#remove-member-#{ctx.member.id}") |> render_click()

      refute has_element?(lv, "#circle-member-#{ctx.member.id}")

      group = Groups.get_group!(ctx.group.id)
      refute Enum.any?(group.user_groups, &(&1.user_id == ctx.member.id))
    end

    test "removing a member revokes their sealed file access (re-add needs catch-up — Task #234)",
         ctx do
      {:ok, file} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())

      {:ok, _} =
        Files.finalize_shared_file_zk(file, [
          %{"user_id" => ctx.admin.id, "sealed_key" => "sealed-#{ctx.admin.id}"},
          %{"user_id" => ctx.member.id, "sealed_key" => "sealed-#{ctx.member.id}"}
        ])

      refute is_nil(Files.get_user_shared_file(file, ctx.member))

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      lv |> element("#remove-member-#{ctx.member.id}") |> render_click()

      assert is_nil(Files.get_user_shared_file(file, ctx.member))
      assert {:error, :unauthorized} = Files.presigned_download_url(file, ctx.member)
    end

    test "a plain member has no Remove affordance and a tampered remove is refused", ctx do
      # A second org member added to the circle so the viewer has someone to try
      # to remove.
      {orgmate, _key} = onboarded_user("csremtarget")
      add_member(ctx.org, orgmate, :member)

      {:ok, lv0, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      render_hook(lv0, "finalize_group_members_zk", %{"sealed_members" => [sealed_for(orgmate)]})
      confirm_membership(ctx.group, orgmate)

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.member, ctx.member_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      # A plain member sees no remove buttons for others.
      refute has_element?(lv, "#remove-member-#{orgmate.id}")
      refute has_element?(lv, "#remove-member-#{ctx.admin.id}")

      # A tampered client pushing the event must be refused server-side.
      render_hook(lv, "remove_member", %{"user_id" => orgmate.id})

      group = Groups.get_group!(ctx.group.id)
      assert Enum.any?(group.user_groups, &(&1.user_id == orgmate.id))
    end

    test "the circle owner can never be removed even via a tampered event", ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.member, ctx.member_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      render_hook(lv, "remove_member", %{"user_id" => ctx.admin.id})

      group = Groups.get_group!(ctx.group.id)
      assert Enum.any?(group.user_groups, &(&1.user_id == ctx.admin.id))
    end

    test "realtime: a removed member with the circle open is bounced to the org dashboard",
         ctx do
      # The member has the circle open; the admin removes them from another
      # session. The org-update broadcast must bounce the member live.
      {:ok, member_lv, _html} =
        ctx.conn
        |> log_in(ctx.member, ctx.member_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      {:ok, admin_lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      admin_lv |> element("#remove-member-#{ctx.member.id}") |> render_click()

      assert_redirect(member_lv, "/app/business/#{ctx.org.slug}")
    end
  end

  describe "catch up (later-joining members access earlier files — Task #232)" do
    # Adds + confirms a brand-new org member into the circle AFTER a file exists.
    defp join_late(ctx, seed) do
      {late, _lk} = onboarded_user(seed)
      add_member(ctx.org, late, :member)

      {:ok, _} =
        Groups.add_group_members_zk(ctx.group, [
          %{
            "user_id" => late.id,
            "sealed_key" => "sealed-#{late.id}",
            "encrypted_name" => "name-#{late.id}",
            "encrypted_moniker" => "moniker-#{late.id}",
            "encrypted_avatar_img" => "avatar-#{late.id}"
          }
        ])

      confirm_membership(ctx.group, late)
      late
    end

    defp share_file_to(ctx, recipients) do
      {:ok, file} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())

      sealed =
        Enum.map(recipients, fn u ->
          %{"user_id" => u.id, "sealed_key" => "sealed-#{u.id}"}
        end)

      {:ok, _} = Files.finalize_shared_file_zk(file, sealed)
      file
    end

    test "the catch-up button is shown to an authorized reader when a member is missing access",
         ctx do
      share_file_to(ctx, [ctx.admin, ctx.member])
      _late = join_late(ctx, "cscatchlate1")

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      assert has_element?(lv, "#catch-up-button")
    end

    test "the catch-up button is hidden when everyone can already read every file", ctx do
      # No late joiner: the file's readers cover all current members.
      share_file_to(ctx, [ctx.admin, ctx.member])

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      refute has_element?(lv, "#catch-up-button")
    end

    test "an unauthorized member (non-uploader, non-admin) sees no catch-up button", ctx do
      # The admin uploads a file the member can read; a late member is missing
      # access. The plain member is NOT authorized to catch others up.
      share_file_to(ctx, [ctx.admin, ctx.member])
      _late = join_late(ctx, "cscatchlate2")

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.member, ctx.member_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      refute has_element?(lv, "#catch-up-button")
    end

    test "a late-joining ORG ADMIN who is themselves missing files sees no catch-up button (Task #233)",
         ctx do
      # A file is shared while only admin+member are present.
      share_file_to(ctx, [ctx.admin, ctx.member])

      # A separate org ADMIN joins the circle AFTER the file was shared, so they
      # hold no key for it. Even though their org role would normally authorize a
      # catch-up, they can't re-seal a file they can't read — so the affordance
      # must be hidden, and an honest "missing earlier files" hint shown instead.
      {late_admin, late_admin_key} = onboarded_user("cscatchlateadmin")
      add_member(ctx.org, late_admin, :admin)

      {:ok, _} =
        Groups.add_group_members_zk(ctx.group, [sealed_for(late_admin)])

      confirm_membership(ctx.group, late_admin)

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(late_admin, late_admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      refute has_element?(lv, "#catch-up-button")
      assert has_element?(lv, "#catch-up-viewer-missing-hint")
    end

    test "a full-reader admin DOES see the catch-up button while a late member is missing (Task #233)",
         ctx do
      share_file_to(ctx, [ctx.admin, ctx.member])
      _late = join_late(ctx, "cscatchfullreader")

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      # The owner/org-admin can read every file, so they CAN catch others up.
      assert has_element?(lv, "#catch-up-button")
      refute has_element?(lv, "#catch-up-viewer-missing-hint")
    end

    test "finalize_catch_up_zk by an authorized actor grants the late member access", ctx do
      file = share_file_to(ctx, [ctx.admin, ctx.member])
      late = join_late(ctx, "cscatchlate3")

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      # Phase 1 authorizes + builds the payload (browser would re-seal).
      render_hook(lv, "request_catch_up", %{})

      # Phase 2: the browser returns the re-sealed entry.
      render_hook(lv, "finalize_catch_up_zk", %{
        "sealed_entries" => [
          %{
            "shared_file_id" => file.id,
            "user_id" => late.id,
            "sealed_key" => "resealed-#{late.id}"
          }
        ]
      })

      assert Files.get_user_shared_file(file, late).key == "resealed-#{late.id}"
    end

    test "a tampered, unauthorized finalize_catch_up_zk is refused server-side", ctx do
      file = share_file_to(ctx, [ctx.admin, ctx.member])
      late = join_late(ctx, "cscatchlate4")

      # The plain member is not authorized to catch anyone up.
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.member, ctx.member_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      render_hook(lv, "request_catch_up", %{})

      render_hook(lv, "finalize_catch_up_zk", %{
        "sealed_entries" => [
          %{
            "shared_file_id" => file.id,
            "user_id" => late.id,
            "sealed_key" => "resealed-#{late.id}"
          }
        ]
      })

      # The late member still has no access — the unauthorized write was refused.
      assert is_nil(Files.get_user_shared_file(file, late))
    end

    test "realtime: an uploaded file refreshes the Files panel without a reload", ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.member, ctx.member_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      file = share_file_to(ctx, [ctx.admin, ctx.member])

      # The finalize above broadcast {:shared_files_updated, group_id} to the
      # circle's group topic, which CircleShow handles by refreshing live.
      assert render(lv) =~ "shared-file-#{file.id}"
      assert has_element?(lv, "#shared-file-#{file.id}")
    end
  end
end

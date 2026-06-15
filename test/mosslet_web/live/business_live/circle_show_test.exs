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

      assert render(lv) =~ "Who can read these files"
      assert render(lv) =~ "recall copies already downloaded"
    end
  end
end

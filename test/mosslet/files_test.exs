defmodule Mosslet.FilesTest do
  use Mosslet.DataCase, async: false

  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Files
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

  # Confirms an invited member's UserGroup so they become a full circle member.
  defp confirm_membership(group, user) do
    ug = Enum.find(Groups.get_group!(group.id).user_groups, &(&1.user_id == user.id))

    {:ok, {:ok, _}} =
      Mosslet.Repo.transaction_on_primary(fn ->
        ug |> Mosslet.Groups.UserGroup.confirm_changeset() |> Mosslet.Repo.update()
      end)

    :ok
  end

  defp file_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        "storage_path" => "uploads/files/#{Ecto.UUID.generate()}.bin",
        "encrypted_filename" => "encrypted-filename-blob",
        "checksum" => "sha256-checksum-blob",
        "size_bytes" => 1024
      },
      overrides
    )
  end

  setup do
    {admin, _ak} = onboarded_user("filesadmin")
    {:ok, org} = Mosslet.Orgs.create_org(admin, %{"name" => "Filescorp", "type" => "business"})

    {member, _mk} = onboarded_user("filesmember")
    add_member(org, member, :member)

    {outsider, _ok} = onboarded_user("filesoutsider")

    {:ok, group} =
      Groups.create_business_circle_zk(org, admin, zk_attrs(), [member], [sealed_for(member)])

    confirm_membership(group, member)

    %{org: org, group: group, admin: admin, member: member, outsider: outsider}
  end

  describe "create_shared_file_zk/3" do
    test "creates a shared file for an eligible uploader and stamps FKs", ctx do
      assert {:ok, shared_file} =
               Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())

      assert shared_file.group_id == ctx.group.id
      assert shared_file.org_id == ctx.org.id
      assert shared_file.uploader_id == ctx.admin.id
      assert shared_file.size_bytes == 1024
    end

    test "rejects an uploader who is not a circle member", ctx do
      assert {:error, :not_a_circle_member} =
               Files.create_shared_file_zk(ctx.group, ctx.outsider, file_attrs())
    end

    test "rejects a file over the 50 MB cap", ctx do
      oversized = file_attrs(%{"size_bytes" => Files.max_size_bytes() + 1})
      assert {:error, :too_large} = Files.create_shared_file_zk(ctx.group, ctx.admin, oversized)
    end

    test "rejects a non-org (personal) circle", ctx do
      {:ok, personal} = Groups.create_group_zk(zk_attrs(), ctx.admin, [], [])
      assert is_nil(personal.org_id)

      assert {:error, :not_an_org_circle} =
               Files.create_shared_file_zk(personal, ctx.admin, file_attrs())
    end
  end

  describe "finalize_shared_file_zk/2 (I1 eligibility)" do
    test "seals only for confirmed circle members, dropping an outsider", ctx do
      {:ok, shared_file} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())

      sealed = [
        %{"user_id" => ctx.admin.id, "sealed_key" => "sealed-admin"},
        %{"user_id" => ctx.member.id, "sealed_key" => "sealed-member"},
        %{"user_id" => ctx.outsider.id, "sealed_key" => "sealed-outsider"}
      ]

      assert {:ok, 2} = Files.finalize_shared_file_zk(shared_file, sealed)

      reader_ids = shared_file |> Files.list_readers() |> Enum.map(& &1.id)
      assert ctx.admin.id in reader_ids
      assert ctx.member.id in reader_ids
      refute ctx.outsider.id in reader_ids
    end

    test "drops entries without a sealed_key", ctx do
      {:ok, shared_file} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())

      sealed = [
        %{"user_id" => ctx.admin.id, "sealed_key" => "sealed-admin"},
        %{"user_id" => ctx.member.id, "sealed_key" => nil}
      ]

      assert {:ok, 1} = Files.finalize_shared_file_zk(shared_file, sealed)
      assert [%{id: id}] = Files.list_readers(shared_file)
      assert id == ctx.admin.id
    end
  end

  describe "list_shared_files_for_group/2 + list_org_shared_files_for_user/2" do
    test "lists only files the user can read, newest first", ctx do
      {:ok, file1} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())
      {:ok, _} = Files.finalize_shared_file_zk(file1, [sealed_key(ctx.admin)])

      {:ok, file2} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())

      {:ok, _} =
        Files.finalize_shared_file_zk(file2, [sealed_key(ctx.admin), sealed_key(ctx.member)])

      admin_files = Files.list_shared_files_for_group(ctx.group, ctx.admin)
      assert Enum.map(admin_files, & &1.id) |> Enum.sort() == Enum.sort([file1.id, file2.id])

      # The member only holds a key for file2.
      member_files = Files.list_shared_files_for_group(ctx.group, ctx.member)
      assert Enum.map(member_files, & &1.id) == [file2.id]
    end

    test "org overview returns files with :group preloaded, reader-scoped", ctx do
      {:ok, file} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())
      {:ok, _} = Files.finalize_shared_file_zk(file, [sealed_key(ctx.admin)])

      assert [overview] = Files.list_org_shared_files_for_user(ctx.org.id, ctx.admin)
      assert overview.id == file.id
      assert overview.group.id == ctx.group.id

      # The member doesn't hold a key for this file -> empty overview.
      assert Files.list_org_shared_files_for_user(ctx.org.id, ctx.member) == []
    end
  end

  describe "presigned_download_url/2 (auth gate)" do
    test "refuses a non-reader with {:error, :unauthorized}", ctx do
      {:ok, file} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())
      {:ok, _} = Files.finalize_shared_file_zk(file, [sealed_key(ctx.admin)])

      assert {:error, :unauthorized} = Files.presigned_download_url(file, ctx.outsider)
      assert {:error, :unauthorized} = Files.presigned_download_url(file, ctx.member)
    end
  end

  describe "get_user_shared_file/2 + list_readers/1 (I4 transparency)" do
    test "returns the requester's sealed key row only when they're a reader", ctx do
      {:ok, file} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())
      {:ok, _} = Files.finalize_shared_file_zk(file, [sealed_key(ctx.admin)])

      usf = Files.get_user_shared_file(file, ctx.admin)
      assert usf.key == "sealed-#{ctx.admin.id}"

      assert is_nil(Files.get_user_shared_file(file, ctx.outsider))
    end

    test "list_readers returns exactly the current readers", ctx do
      {:ok, file} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())

      {:ok, _} =
        Files.finalize_shared_file_zk(file, [sealed_key(ctx.admin), sealed_key(ctx.member)])

      reader_ids = file |> Files.list_readers() |> Enum.map(& &1.id) |> Enum.sort()
      assert reader_ids == Enum.sort([ctx.admin.id, ctx.member.id])
    end
  end

  describe "delete_shared_file/2 (I5 revocation)" do
    test "uploader can delete; removes record + all sealed keys", ctx do
      {:ok, file} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())

      {:ok, _} =
        Files.finalize_shared_file_zk(file, [sealed_key(ctx.admin), sealed_key(ctx.member)])

      assert {:ok, :revoked} = Files.delete_shared_file(file, ctx.admin)

      assert is_nil(Files.get_shared_file(file.id))
      assert Files.list_readers(file) == []
    end

    test "a circle admin/owner can delete another member's file", ctx do
      # The member uploads, the owner (admin) revokes.
      {:ok, file} = Files.create_shared_file_zk(ctx.group, ctx.member, file_attrs())
      {:ok, _} = Files.finalize_shared_file_zk(file, [sealed_key(ctx.member)])

      assert {:ok, :revoked} = Files.delete_shared_file(file, ctx.admin)
      assert is_nil(Files.get_shared_file(file.id))
    end

    test "a non-uploader non-admin member cannot delete", ctx do
      {:ok, file} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())
      {:ok, _} = Files.finalize_shared_file_zk(file, [sealed_key(ctx.member)])

      assert {:error, :unauthorized} = Files.delete_shared_file(file, ctx.member)
      refute is_nil(Files.get_shared_file(file.id))
    end
  end

  describe "revoke_member_file_access/2 (Q6 departed-member revocation)" do
    test "removes a member's sealed keys across all of the circle's files", ctx do
      {:ok, file1} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())

      {:ok, _} =
        Files.finalize_shared_file_zk(file1, [sealed_key(ctx.admin), sealed_key(ctx.member)])

      {:ok, file2} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())

      {:ok, _} =
        Files.finalize_shared_file_zk(file2, [sealed_key(ctx.admin), sealed_key(ctx.member)])

      assert {:ok, 2} = Files.revoke_member_file_access(ctx.group, ctx.member.id)

      # The member can no longer read either file; the admin still can.
      assert is_nil(Files.get_user_shared_file(file1, ctx.member))
      assert is_nil(Files.get_user_shared_file(file2, ctx.member))
      refute is_nil(Files.get_user_shared_file(file1, ctx.admin))
      refute is_nil(Files.get_user_shared_file(file2, ctx.admin))
    end
  end

  describe "delete_all_for_group/1 + circle deletion teardown (I5)" do
    test "removes every shared file + reader row for the circle", ctx do
      {:ok, file1} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())

      {:ok, _} =
        Files.finalize_shared_file_zk(file1, [sealed_key(ctx.admin), sealed_key(ctx.member)])

      {:ok, file2} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())
      {:ok, _} = Files.finalize_shared_file_zk(file2, [sealed_key(ctx.admin)])

      assert {:ok, 2} = Files.delete_all_for_group(ctx.group)

      assert is_nil(Files.get_shared_file(file1.id))
      assert is_nil(Files.get_shared_file(file2.id))
      assert Files.list_shared_files_for_group(ctx.group, ctx.admin) == []
    end

    test "returns {:ok, 0} for a circle with no files", ctx do
      assert {:ok, 0} = Files.delete_all_for_group(ctx.group)
    end

    test "Groups.delete_group tears down the circle's shared files first", ctx do
      {:ok, file} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())
      {:ok, _} = Files.finalize_shared_file_zk(file, [sealed_key(ctx.admin)])

      assert {:ok, _} = Groups.delete_group(ctx.group)

      # Both the SharedFile row and the circle are gone (no orphaned DB rows;
      # blob teardown was triggered too).
      assert is_nil(Files.get_shared_file(file.id))
    end
  end

  describe "delete_all_for_org/1 (org teardown, board #227)" do
    test "removes every shared file across the org's circles", ctx do
      {:ok, file} = Files.create_shared_file_zk(ctx.group, ctx.admin, file_attrs())
      {:ok, _} = Files.finalize_shared_file_zk(file, [sealed_key(ctx.admin)])

      assert {:ok, 1} = Files.delete_all_for_org(ctx.org.id)
      assert is_nil(Files.get_shared_file(file.id))
    end
  end

  defp sealed_key(user), do: %{"user_id" => user.id, "sealed_key" => "sealed-#{user.id}"}
end

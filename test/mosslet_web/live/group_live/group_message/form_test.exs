defmodule MossletWeb.GroupLive.GroupMessage.FormTest do
  @moduledoc """
  Circle chat @mention member payload (Task #282).

  Regression coverage for the bug where the @mention picker's avatars/members
  sometimes didn't load until a hard refresh. The fix stops relying on a
  transient `push_event("set_members")` (which LiveView does NOT buffer for a
  hook that hasn't registered its handler yet, so members were dropped on
  connected mount / live-navigation) and instead embeds the member payload as a
  `data-members` JSON attribute on the form. The JS hook reads it race-free in
  `mounted()`/`updated()`.

  These tests assert the server embeds a well-formed, ZK-safe payload. The JS
  timing fix itself is verified in-browser.
  """
  use MossletWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Accounts.Scope
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

  defp onboarded_user(name_seed) do
    email = "#{name_seed}#{System.unique_integer([:positive])}@example.com"
    username = "#{name_seed}#{System.unique_integer([:positive])}"
    user = user_fixture(%{email: email, username: username, password: @password})
    user = Accounts.confirm_user!(user)
    {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})
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

  # Render the form LiveComponent for `viewer` in the given private business
  # circle and return the decoded `data-members` payload.
  defp render_members(group, viewer, viewer_key, opts \\ []) do
    sender_ug =
      Groups.get_group!(group.id).user_groups
      |> Enum.find(&(&1.user_id == viewer.id))

    html =
      render_component(
        MossletWeb.GroupLive.GroupMessage.Form,
        [
          id: "group-message-form",
          group_id: group.id,
          current_scope: Scope.for_user(viewer, key: viewer_key),
          user_group_key: "sealed-group-key",
          sender_id: sender_ug.id,
          public?: false,
          current_page: :business
        ] ++ opts
      )

    [json] =
      html
      |> Floki.parse_fragment!()
      |> Floki.attribute("#group-message-form", "data-members")

    {html, Jason.decode!(json)}
  end

  setup do
    {admin, admin_key} = onboarded_user("fadmin")
    {:ok, org} = Orgs.create_org(admin, %{"name" => "FormBizCo", "type" => "business"})

    {member, _member_key} = onboarded_user("fmember")
    add_member(org, member, :member)

    {:ok, group} =
      Groups.create_business_circle_zk(org, admin, zk_attrs(), [member], [sealed_for(member)])

    confirm_membership(group, member)

    %{org: org, group: group, admin: admin, admin_key: admin_key, member: member}
  end

  describe "data-members payload (Task #282)" do
    test "form embeds a data-members attribute (no reliance on push_event)", ctx do
      {html, members} = render_members(ctx.group, ctx.admin, ctx.admin_key)

      assert html =~ ~s|id="group-message-form"|
      assert is_list(members)
      # One confirmed member per UserGroup (admin + member).
      assert length(members) == 2
    end

    test "private-circle members carry ciphertext only — never plaintext monikers", ctx do
      {_html, members} = render_members(ctx.group, ctx.admin, ctx.admin_key)

      for member <- members do
        assert member["browser_decrypt"] == true
        assert is_binary(member["user_group_id"])
        # ZK invariant: the moniker is shipped only as ciphertext for the
        # browser to decrypt; the server-side decrypted plaintext is never sent.
        assert is_binary(member["encrypted_moniker"])
        assert is_nil(member["moniker"])
      end
    end
  end

  describe "org display name in the @mention picker (Task #283)" do
    test "ships a non-connected member's org display-name ciphertext + sealed org key", ctx do
      member_membership = Orgs.get_membership!(ctx.member, ctx.org.slug)
      {:ok, _} = Orgs.set_org_display_name(member_membership, "ct-org-display-name")

      directory = %{ctx.member.id => "ct-org-display-name"}

      {html, members} =
        render_members(ctx.group, ctx.admin, ctx.admin_key,
          org_display_names: directory,
          viewer_sealed_org_key: "sealed-org-key-blob"
        )

      # The viewer's sealed org_key lets the browser unseal the shared org_key.
      assert html =~ ~s|data-sealed-org-key="sealed-org-key-blob"|

      member = Enum.find(members, &(&1["user_group_id"] != self_user_group_id(ctx)))
      assert member["encrypted_org_display_name"] == "ct-org-display-name"
      # ZK: only ciphertext is shipped — never a server-decrypted org name.
      refute member["org_display_name"]
    end

    test "never ships the viewer's own org display name (self shows 'You')", ctx do
      directory = %{ctx.admin.id => "ct-self-org-name", ctx.member.id => "ct-member-org-name"}

      {_html, members} =
        render_members(ctx.group, ctx.admin, ctx.admin_key,
          org_display_names: directory,
          viewer_sealed_org_key: "sealed-org-key-blob"
        )

      self_member = Enum.find(members, &(&1["user_group_id"] == self_user_group_id(ctx)))
      assert is_nil(self_member["encrypted_org_display_name"])
    end
  end

  describe "org display AVATAR in the @mention picker (Task #277)" do
    test "ships a non-connected member's org avatar ciphertext + sealed org key", ctx do
      member_membership = Orgs.get_membership!(ctx.member, ctx.org.slug)
      {:ok, _} = Orgs.set_org_avatar(member_membership, "ct-org-avatar-blob")

      directory = %{ctx.member.id => "ct-org-avatar-blob"}

      {html, members} =
        render_members(ctx.group, ctx.admin, ctx.admin_key,
          org_avatars: directory,
          viewer_sealed_org_key: "sealed-org-key-blob"
        )

      # The viewer's sealed org_key lets the browser unseal the shared org_key
      # and decrypt the org avatar.
      assert html =~ ~s|data-sealed-org-key="sealed-org-key-blob"|

      member = Enum.find(members, &(&1["user_group_id"] != self_user_group_id(ctx)))
      assert member["encrypted_org_avatar"] == "ct-org-avatar-blob"
    end

    test "never ships the viewer's own org avatar (persona separation)", ctx do
      directory = %{ctx.admin.id => "ct-self-avatar", ctx.member.id => "ct-member-avatar"}

      {_html, members} =
        render_members(ctx.group, ctx.admin, ctx.admin_key,
          org_avatars: directory,
          viewer_sealed_org_key: "sealed-org-key-blob"
        )

      self_member = Enum.find(members, &(&1["user_group_id"] == self_user_group_id(ctx)))
      assert is_nil(self_member["encrypted_org_avatar"])
    end
  end

  defp self_user_group_id(ctx) do
    Groups.get_group!(ctx.group.id).user_groups
    |> Enum.find(&(&1.user_id == ctx.admin.id))
    |> Map.fetch!(:id)
  end
end

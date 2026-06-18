defmodule Mosslet.PinsTest do
  use Mosslet.DataCase, async: false

  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Groups
  alias Mosslet.Pins

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

  defp link_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        "pin_type" => :link,
        "encrypted_label" => "encrypted-label-blob",
        "encrypted_url" => "encrypted-url-blob"
      },
      overrides
    )
  end

  setup do
    {owner, _ak} = onboarded_user("pinowner")
    {:ok, org} = Mosslet.Orgs.create_org(owner, %{"name" => "Pincorp", "type" => "business"})

    {admin, _adk} = onboarded_user("pinadmin")
    add_member(org, admin, :admin)

    {member, _mk} = onboarded_user("pinmember")
    add_member(org, member, :member)

    {outsider, _ok} = onboarded_user("pinoutsider")

    {:ok, group} =
      Groups.create_business_circle_zk(org, owner, zk_attrs(), [member], [sealed_for(member)])

    %{org: org, group: group, owner: owner, admin: admin, member: member, outsider: outsider}
  end

  describe "org-wide pin authority (I1)" do
    test "org owner can create an org-wide link pin", ctx do
      assert {:ok, pin} = Pins.create_org_shared_pin(ctx.org, ctx.owner, link_attrs())
      assert pin.org_id == ctx.org.id
      assert pin.scope == :org_shared
      assert is_nil(pin.user_id)
      assert pin.created_by_id == ctx.owner.id
      assert pin.pin_type == :link
    end

    test "org admin can create an org-wide pin", ctx do
      assert {:ok, _pin} = Pins.create_org_shared_pin(ctx.org, ctx.admin, link_attrs())
    end

    test "a plain member cannot create an org-wide pin", ctx do
      assert {:error, :unauthorized} =
               Pins.create_org_shared_pin(ctx.org, ctx.member, link_attrs())
    end

    test "a non-member cannot create an org-wide pin", ctx do
      assert {:error, :unauthorized} =
               Pins.create_org_shared_pin(ctx.org, ctx.outsider, link_attrs())
    end

    test "can_manage_org_pins?/2 reflects owner/admin only", ctx do
      assert Pins.can_manage_org_pins?(ctx.org, ctx.owner.id)
      assert Pins.can_manage_org_pins?(ctx.org, ctx.admin.id)
      refute Pins.can_manage_org_pins?(ctx.org, ctx.member.id)
      refute Pins.can_manage_org_pins?(ctx.org, ctx.outsider.id)
    end
  end

  describe "personal pin authority (I1)" do
    test "any member can create a personal pin", ctx do
      assert {:ok, pin} = Pins.create_personal_pin(ctx.org, ctx.member, link_attrs())
      assert pin.scope == :personal
      assert pin.user_id == ctx.member.id
      assert pin.created_by_id == ctx.member.id
    end

    test "owner/admin can also create personal pins", ctx do
      assert {:ok, _} = Pins.create_personal_pin(ctx.org, ctx.owner, link_attrs())
      assert {:ok, _} = Pins.create_personal_pin(ctx.org, ctx.admin, link_attrs())
    end

    test "a non-member cannot create a personal pin", ctx do
      assert {:error, :unauthorized} =
               Pins.create_personal_pin(ctx.org, ctx.outsider, link_attrs())
    end
  end

  describe "pin types" do
    test "circle pin stores the target FK and no link ciphertext", ctx do
      assert {:ok, pin} =
               Pins.create_personal_pin(ctx.org, ctx.member, %{
                 "pin_type" => :circle,
                 "target_id" => ctx.group.id
               })

      assert pin.pin_type == :circle
      assert pin.target_id == ctx.group.id
      assert is_nil(pin.encrypted_label)
      assert is_nil(pin.encrypted_url)
    end

    test "file pin stores the target FK", ctx do
      file_id = Ecto.UUID.generate()

      assert {:ok, pin} =
               Pins.create_org_shared_pin(ctx.org, ctx.owner, %{
                 "pin_type" => :file,
                 "target_id" => file_id
               })

      assert pin.pin_type == :file
      assert pin.target_id == file_id
    end

    test "link pin requires the encrypted label + URL", ctx do
      assert {:error, changeset} =
               Pins.create_personal_pin(ctx.org, ctx.member, %{"pin_type" => :link})

      refute changeset.valid?
      assert %{encrypted_url: _} = errors_on(changeset)
    end

    test "circle/file pin requires a target_id", ctx do
      assert {:error, changeset} =
               Pins.create_personal_pin(ctx.org, ctx.member, %{"pin_type" => :circle})

      refute changeset.valid?
      assert %{target_id: _} = errors_on(changeset)
    end

    test "parse_pin_type/1 maps known values and rejects junk" do
      assert Pins.parse_pin_type("circle") == :circle
      assert Pins.parse_pin_type("file") == :file
      assert Pins.parse_pin_type("link") == :link
      assert Pins.parse_pin_type("nope") == nil
    end
  end

  describe "org + scope scoping" do
    test "list_org_shared_pins/1 returns only this org's shared pins (not personal)", ctx do
      {:ok, _shared} = Pins.create_org_shared_pin(ctx.org, ctx.owner, link_attrs())
      {:ok, _personal} = Pins.create_personal_pin(ctx.org, ctx.member, link_attrs())

      shared = Pins.list_org_shared_pins(ctx.org)
      assert length(shared) == 1
      assert Enum.all?(shared, &(&1.scope == :org_shared))
      assert Enum.all?(shared, &is_nil(&1.user_id))
    end

    test "list_personal_pins/2 is scoped to the viewer", ctx do
      {:ok, _mine} = Pins.create_personal_pin(ctx.org, ctx.member, link_attrs())
      {:ok, _theirs} = Pins.create_personal_pin(ctx.org, ctx.owner, link_attrs())

      mine = Pins.list_personal_pins(ctx.org, ctx.member)
      assert length(mine) == 1
      assert Enum.all?(mine, &(&1.user_id == ctx.member.id))
    end

    test "pins are isolated to their org", ctx do
      {other_owner, _k} = onboarded_user("pinotherowner")

      {:ok, other_org} =
        Mosslet.Orgs.create_org(other_owner, %{"name" => "Othercorp", "type" => "business"})

      {:ok, _here} = Pins.create_org_shared_pin(ctx.org, ctx.owner, link_attrs())

      assert Pins.list_org_shared_pins(other_org) == []
    end
  end

  describe "delete authority" do
    test "the owner of a personal pin can delete it", ctx do
      {:ok, pin} = Pins.create_personal_pin(ctx.org, ctx.member, link_attrs())
      assert {:ok, :deleted} = Pins.delete_pin(pin, ctx.member)
      assert Pins.list_personal_pins(ctx.org, ctx.member) == []
    end

    test "another member cannot delete someone's personal pin", ctx do
      {:ok, pin} = Pins.create_personal_pin(ctx.org, ctx.member, link_attrs())
      assert {:error, :unauthorized} = Pins.delete_pin(pin, ctx.owner)
    end

    test "an org admin can delete an org-wide pin", ctx do
      {:ok, pin} = Pins.create_org_shared_pin(ctx.org, ctx.owner, link_attrs())
      assert {:ok, :deleted} = Pins.delete_pin(pin, ctx.admin)
    end

    test "a plain member cannot delete an org-wide pin", ctx do
      {:ok, pin} = Pins.create_org_shared_pin(ctx.org, ctx.owner, link_attrs())
      assert {:error, :unauthorized} = Pins.delete_pin(pin, ctx.member)
    end
  end

  describe "toggle lookups" do
    test "get_personal_target_pin/4 finds the viewer's circle pin", ctx do
      {:ok, pin} =
        Pins.create_personal_pin(ctx.org, ctx.member, %{
          "pin_type" => :circle,
          "target_id" => ctx.group.id
        })

      assert %{id: id} = Pins.get_personal_target_pin(ctx.org, ctx.member, :circle, ctx.group.id)
      assert id == pin.id
      assert is_nil(Pins.get_personal_target_pin(ctx.org, ctx.owner, :circle, ctx.group.id))
    end

    test "get_org_shared_target_pin/3 finds the org-wide circle pin", ctx do
      {:ok, pin} =
        Pins.create_org_shared_pin(ctx.org, ctx.owner, %{
          "pin_type" => :circle,
          "target_id" => ctx.group.id
        })

      assert %{id: id} = Pins.get_org_shared_target_pin(ctx.org, :circle, ctx.group.id)
      assert id == pin.id
    end
  end

  describe "ordering + reordering (position)" do
    test "new pins append with increasing position; lists order by position", ctx do
      {:ok, a} = Pins.create_personal_pin(ctx.org, ctx.member, link_attrs())
      {:ok, b} = Pins.create_personal_pin(ctx.org, ctx.member, link_attrs())
      {:ok, c} = Pins.create_personal_pin(ctx.org, ctx.member, link_attrs())

      assert a.position < b.position
      assert b.position < c.position

      assert Enum.map(Pins.list_personal_pins(ctx.org, ctx.member), & &1.id) == [a.id, b.id, c.id]
    end

    test "reorder_personal_pins/3 rewrites position to match the new order", ctx do
      {:ok, a} = Pins.create_personal_pin(ctx.org, ctx.member, link_attrs())
      {:ok, b} = Pins.create_personal_pin(ctx.org, ctx.member, link_attrs())
      {:ok, c} = Pins.create_personal_pin(ctx.org, ctx.member, link_attrs())

      assert :ok = Pins.reorder_personal_pins(ctx.org, ctx.member, [c.id, a.id, b.id])

      assert Enum.map(Pins.list_personal_pins(ctx.org, ctx.member), & &1.id) == [c.id, a.id, b.id]
    end

    test "reorder ignores ids from another scope/owner (no cross tampering)", ctx do
      {:ok, mine} = Pins.create_personal_pin(ctx.org, ctx.member, link_attrs())
      {:ok, theirs} = Pins.create_personal_pin(ctx.org, ctx.owner, link_attrs())

      assert :ok = Pins.reorder_personal_pins(ctx.org, ctx.member, [theirs.id, mine.id])

      # `theirs` is untouched; only `mine` (the single eligible id) is repositioned.
      assert Enum.map(Pins.list_personal_pins(ctx.org, ctx.member), & &1.id) == [mine.id]
      refreshed_theirs = Pins.get_pin(theirs.id)
      assert refreshed_theirs.position == theirs.position
    end

    test "a plain member cannot reorder org-wide pins", ctx do
      {:ok, _a} = Pins.create_org_shared_pin(ctx.org, ctx.owner, link_attrs())

      assert {:error, :unauthorized} =
               Pins.reorder_org_shared_pins(ctx.org, ctx.member, [])
    end

    test "an admin can reorder org-wide pins", ctx do
      {:ok, a} = Pins.create_org_shared_pin(ctx.org, ctx.owner, link_attrs())
      {:ok, b} = Pins.create_org_shared_pin(ctx.org, ctx.owner, link_attrs())

      assert :ok = Pins.reorder_org_shared_pins(ctx.org, ctx.admin, [b.id, a.id])
      assert Enum.map(Pins.list_org_shared_pins(ctx.org), & &1.id) == [b.id, a.id]
    end
  end

  describe "realtime (org-wide pins, id-only)" do
    test "creating an org-wide pin broadcasts an id-only event on the org topic", ctx do
      Phoenix.PubSub.subscribe(Mosslet.PubSub, "org:#{ctx.org.id}")

      {:ok, _pin} = Pins.create_org_shared_pin(ctx.org, ctx.owner, link_attrs())

      assert_receive {:pins_updated, %{scope: :org_shared, org_id: org_id}}
      assert org_id == ctx.org.id
    end

    test "creating a personal pin does NOT broadcast", ctx do
      Phoenix.PubSub.subscribe(Mosslet.PubSub, "org:#{ctx.org.id}")

      {:ok, _pin} = Pins.create_personal_pin(ctx.org, ctx.member, link_attrs())

      refute_receive {:pins_updated, _}
    end
  end
end

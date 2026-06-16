defmodule Mosslet.OrgsLimitsTest do
  use Mosslet.DataCase, async: true

  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Orgs

  # A confirmed user. Org creation no longer requires a personal (:user)
  # subscription — personal and org billing are fully independent (Task #235).
  # Creating an org requires only a confirmed user; the org is activated by
  # purchasing its own `:org`-source plan.
  defp confirmed_user(seed) do
    confirmed_user_no_billing(seed)
  end

  # A confirmed user with NO billing of any kind.
  defp confirmed_user_no_billing(seed) do
    email = "#{seed}#{System.unique_integer([:positive])}@example.com"

    user_fixture(%{email: email})
    |> Accounts.confirm_user!()
  end

  # Attaches an active personal (:user) subscription. Personal billing is
  # independent of org coverage — used only to assert that it does NOT grant
  # org coverage or gate org creation.
  defp subscribe_user(user) do
    {:ok, customer} =
      Customers.create_customer_for_source(:user, user.id, %{
        email: "billing-#{System.unique_integer([:positive])}@example.com",
        provider: "stripe",
        provider_customer_id: "cus_#{System.unique_integer([:positive])}"
      })

    {:ok, subscription} =
      Subscriptions.create_subscription(%{
        billing_customer_id: customer.id,
        plan_id: "personal-monthly",
        status: "active",
        quantity: 1,
        provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
        provider_subscription_items: [%{price: "price_test"}],
        current_period_start: NaiveDateTime.utc_now()
      })

    {customer, subscription}
  end

  # Attaches an active org-scoped subscription so the org counts as "paid" for
  # the multi-business entitlement + seat-cap source-of-truth checks.
  defp subscribe_org(org, opts \\ []) do
    quantity = Keyword.get(opts, :quantity, 1)
    status = Keyword.get(opts, :status, "active")

    {:ok, customer} =
      Customers.create_customer_for_source(:org, org.id, %{
        email: "billing-#{System.unique_integer([:positive])}@example.com",
        provider: "stripe",
        provider_customer_id: "cus_#{System.unique_integer([:positive])}"
      })

    {:ok, subscription} =
      Subscriptions.create_subscription(%{
        billing_customer_id: customer.id,
        plan_id: "business-monthly",
        status: status,
        quantity: quantity,
        provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
        provider_subscription_items: [%{price: "price_test"}],
        current_period_start: NaiveDateTime.utc_now()
      })

    {customer, subscription}
  end

  describe "create_org/2 ownership" do
    test "stamps created_by_id with the creating user" do
      user = confirmed_user("owner")
      {:ok, org} = Orgs.create_org(user, %{"name" => "Acme", "type" => "business"})

      assert org.created_by_id == user.id
      assert Orgs.owner?(org, user.id)
      refute Orgs.owner?(org, Ecto.UUID.generate())
    end

    test "list_owned_orgs / count_owned_orgs filter by type" do
      user = confirmed_user("owner")
      {:ok, _fam} = Orgs.create_org(user, %{"name" => "Fam", "type" => "family"})
      {:ok, _biz} = Orgs.create_org(user, %{"name" => "Biz", "type" => "business"})

      assert Orgs.count_owned_orgs(user) == 2
      assert Orgs.count_owned_orgs(user, :family) == 1
      assert Orgs.count_owned_orgs(user, :business) == 1
      assert [%{type: :business}] = Orgs.list_owned_orgs(user, :business)
    end
  end

  describe "create_org/2 personal-billing independence (Task #235)" do
    test "a confirmed user with NO billing can still create an org" do
      user = confirmed_user_no_billing("nobilling")

      refute Orgs.user_has_active_billing?(user)

      assert {:ok, _fam} =
               Orgs.create_org(user, %{"name" => "NoPay Fam", "type" => "family"})

      assert {:ok, _biz} =
               Orgs.create_org(user, %{"name" => "NoPay Biz", "type" => "business"})
    end

    test "owning an org does not grant the owner personal billing" do
      user = confirmed_user_no_billing("ownsorg")
      {:ok, _org} = Orgs.create_org(user, %{"name" => "Acme", "type" => "business"})

      # Org creation/ownership is fully independent of the owner's personal plan.
      refute Orgs.user_has_active_billing?(user)
    end

    test "a personal subscription does not block or change org creation" do
      user = confirmed_user_no_billing("haspersonal")
      subscribe_user(user)

      assert Orgs.user_has_active_billing?(user)
      assert {:ok, _org} = Orgs.create_org(user, %{"name" => "Paid Fam", "type" => "family"})
    end
  end

  describe "family ownership limit" do
    test "allows the first owned family" do
      user = confirmed_user("fam")
      assert Orgs.can_create_org?(user, :family)
      assert {:ok, _org} = Orgs.create_org(user, %{"name" => "Smiths", "type" => "family"})
    end

    test "blocks a second owned family" do
      user = confirmed_user("fam")
      {:ok, _org} = Orgs.create_org(user, %{"name" => "Smiths", "type" => "family"})

      refute Orgs.can_create_org?(user, :family)

      assert {:error, :family_limit_reached} =
               Orgs.create_org(user, %{"name" => "Joneses", "type" => "family"})

      assert Orgs.count_owned_orgs(user, :family) == 1
    end

    test "an invited family member-seat (owns none) cannot create a free family" do
      owner = confirmed_user("famowner")
      other = confirmed_user("fammember")
      {:ok, org} = Orgs.create_org(owner, %{"name" => "Smiths", "type" => "family"})

      # `other` joins owner's family but does not own it.
      {:ok, {:ok, _ms}} =
        Repo.transaction_on_primary(fn ->
          Orgs.Membership.insert_changeset(org, other) |> Repo.insert()
        end)

      assert Orgs.count_owned_orgs(other, :family) == 0
      assert Orgs.count_member_orgs(other, :family) == 1

      # A member-seat occupies a seat the org already covers — they must pay to
      # start their OWN family rather than getting a free one. (#224)
      refute Orgs.can_create_org?(other, :family)

      assert {:error, :family_entitlement_required} =
               Orgs.create_org(other, %{"name" => "Joneses", "type" => "family"})
    end

    test "a family member-seat in one type can still create a free org of the other type" do
      owner = confirmed_user("famowner2")
      other = confirmed_user("fammember2")
      {:ok, org} = Orgs.create_org(owner, %{"name" => "Smiths", "type" => "family"})

      {:ok, {:ok, _ms}} =
        Repo.transaction_on_primary(fn ->
          Orgs.Membership.insert_changeset(org, other) |> Repo.insert()
        end)

      # Being a FAMILY member-seat does not block creating a first BUSINESS.
      assert Orgs.count_member_orgs(other, :business) == 0
      assert Orgs.can_create_org?(other, :business)
    end
  end

  describe "business multi-org entitlement" do
    test "first owned business is free" do
      user = confirmed_user("biz")
      assert Orgs.can_create_org?(user, :business)
      assert {:ok, _org} = Orgs.create_org(user, %{"name" => "Acme", "type" => "business"})
    end

    test "second owned business is blocked when the first is unpaid" do
      user = confirmed_user("biz")
      {:ok, _first} = Orgs.create_org(user, %{"name" => "Acme", "type" => "business"})

      refute Orgs.all_owned_businesses_paid?(user)
      refute Orgs.can_create_org?(user, :business)

      assert {:error, :business_entitlement_required} =
               Orgs.create_org(user, %{"name" => "Beta", "type" => "business"})
    end

    test "second owned business is allowed when the first is on an active paid plan" do
      user = confirmed_user("biz")
      {:ok, first} = Orgs.create_org(user, %{"name" => "Acme", "type" => "business"})
      subscribe_org(first)

      assert Orgs.all_owned_businesses_paid?(user)
      assert Orgs.can_create_org?(user, :business)
      assert {:ok, _second} = Orgs.create_org(user, %{"name" => "Beta", "type" => "business"})
    end

    test "a canceled subscription does not satisfy the entitlement" do
      user = confirmed_user("biz")
      {:ok, first} = Orgs.create_org(user, %{"name" => "Acme", "type" => "business"})
      subscribe_org(first, status: "canceled")

      refute Orgs.all_owned_businesses_paid?(user)
      refute Orgs.can_create_org?(user, :business)
    end

    test "a trialing business is NOT yet paid, so it does not unlock a second one" do
      # A free trial is active for coverage/access, but it has not converted to a
      # PAID plan — the multi-business gate must hold until the trial converts.
      user = confirmed_user("biz")
      {:ok, first} = Orgs.create_org(user, %{"name" => "Acme", "type" => "business"})
      subscribe_org(first, status: "trialing")

      # The trialing org is active (usable)...
      assert Orgs.org_active?(first)
      # ...but not yet PAID, so it cannot entitle a second business.
      refute Orgs.org_has_paid_subscription?(first)
      refute Orgs.all_owned_businesses_paid?(user)
      refute Orgs.can_create_org?(user, :business)

      assert {:error, :business_entitlement_required} =
               Orgs.create_org(user, %{"name" => "Beta", "type" => "business"})
    end

    test "an invited business member-seat (owns none) cannot create a free business" do
      owner = confirmed_user("bizowner")
      other = confirmed_user("bizmember")
      {:ok, org} = Orgs.create_org(owner, %{"name" => "Acme", "type" => "business"})

      # `other` is invited in as a member but does not own a business.
      {:ok, {:ok, _ms}} =
        Repo.transaction_on_primary(fn ->
          Orgs.Membership.insert_changeset(org, other) |> Repo.insert()
        end)

      assert Orgs.count_owned_orgs(other, :business) == 0
      assert Orgs.count_member_orgs(other, :business) == 1

      # They may start their OWN business only by paying for it — no free one
      # off a seat the org already covers. (#224)
      refute Orgs.can_create_org?(other, :business)

      assert {:error, :business_entitlement_required} =
               Orgs.create_org(other, %{"name" => "Beta", "type" => "business"})
    end
  end

  describe "seat-cap enforcement (counts pending invites)" do
    setup do
      owner = confirmed_user("seatowner")
      {:ok, org} = Orgs.create_org(owner, %{"name" => "Acme", "type" => "business"})
      %{owner: owner, org: org}
    end

    test "seat_cap falls back to plan included_seats with no subscription", %{org: org} do
      # Business included_seats floor is 10 (config).
      assert Orgs.seat_cap(org) == 10
    end

    test "seat_cap uses the purchased subscription quantity when present", %{org: org} do
      subscribe_org(org, quantity: 2)
      assert Orgs.seat_cap(org) == 2
    end

    test "seat usage counts confirmed members + pending invitations", %{org: org} do
      # 1 confirmed member (the owner/admin) so far.
      assert %{members: 1, pending: 0, used: 1} = Orgs.seat_summary(org)

      {:ok, _inv} = Orgs.create_invitation(org, %{"sent_to" => "pending@example.com"})

      assert %{members: 1, pending: 1, used: 2} = Orgs.seat_summary(org)
    end

    test "invitations are blocked at the cap, counting a pending invite", %{org: org} do
      # Cap the org at 2 seats: owner (1 member) + 1 pending fills it.
      subscribe_org(org, quantity: 2)

      assert {:ok, _inv} = Orgs.create_invitation(org, %{"sent_to" => "first@example.com"})

      # 2 of 2 used (1 member + 1 pending) -> next invite blocked.
      assert %{used: 2, cap: 2, available: 0} = Orgs.seat_summary(org)

      assert {:error, :seat_limit_reached} =
               Orgs.create_invitation(org, %{"sent_to" => "second@example.com"})
    end

    test "check_seat_capacity reflects availability", %{org: org} do
      subscribe_org(org, quantity: 1)
      # owner already fills the single seat.
      assert {:error, :seat_limit_reached} = Orgs.check_seat_capacity(org)
    end
  end
end

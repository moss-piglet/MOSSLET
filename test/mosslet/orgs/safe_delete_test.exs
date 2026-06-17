defmodule Mosslet.Orgs.SafeDeleteTest do
  @moduledoc """
  Tests for owner-facing SAFE org deletion + true ZK teardown (Task #227):
  `Orgs.delete_org_safely/2` and the best-effort `OrgTeardownJob`.
  """
  use Mosslet.DataCase, async: true
  use Oban.Testing, repo: Mosslet.Repo

  import Mosslet.AccountsFixtures
  import Mosslet.OrgsFixtures

  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Groups
  alias Mosslet.Orgs
  alias Mosslet.Orgs.Membership
  alias Mosslet.Orgs.Jobs.OrgTeardownJob

  @password valid_user_password()

  defp add_member(org, user, role) do
    {:ok, {:ok, membership}} =
      Repo.transaction_on_primary(fn ->
        Membership.insert_changeset(org, user, role) |> Repo.insert()
      end)

    membership
  end

  defp setup_org(type \\ "business") do
    owner = user_fixture()
    member = user_fixture()
    org = org_fixture(owner, %{"type" => type})
    add_member(org, member, :member)
    %{owner: owner, member: member, org: org}
  end

  describe "delete_org_safely/2 gates" do
    test "refuses a non-owner without deleting anything" do
      %{member: member, org: org} = setup_org()
      stranger = user_fixture()

      assert {:error, :not_owner} = Orgs.delete_org_safely(org, member, @password)
      assert {:error, :not_owner} = Orgs.delete_org_safely(org, stranger, @password)

      refute is_nil(Orgs.get_org_by_id(org.id))
      refute_enqueued(worker: OrgTeardownJob)
    end

    test "refuses an incorrect password without deleting anything" do
      %{owner: owner, org: org} = setup_org()

      assert {:error, :invalid_password} =
               Orgs.delete_org_safely(org, owner, "definitely-wrong-password")

      refute is_nil(Orgs.get_org_by_id(org.id))
      refute_enqueued(worker: OrgTeardownJob)
    end
  end

  describe "delete_org_safely/2 teardown" do
    test "deletes the org and cascade-removes its memberships" do
      %{owner: owner, member: member, org: org} = setup_org()

      assert length(Orgs.list_members_by_org(org)) == 2

      assert {:ok, summary} = Orgs.delete_org_safely(org, owner, @password)
      assert summary.org_id == org.id

      assert is_nil(Orgs.get_org_by_id(org.id))
      # No membership rows survive for the deleted org.
      refute Orgs.member_of_org?(%{org | id: org.id}, owner.id)
      refute Orgs.member_of_org?(%{org | id: org.id}, member.id)
    end

    test "members keep their personal accounts and personal billing" do
      %{owner: owner, member: member, org: org} = setup_org()

      # Give the MEMBER a personal (:user-source) subscription that must survive.
      ensure_user_subscription(member)
      member_customer = Customers.get_customer_by_source(:user, member.id)
      refute is_nil(member_customer)

      assert {:ok, _summary} = Orgs.delete_org_safely(org, owner, @password)

      # Personal accounts untouched.
      refute is_nil(Mosslet.Accounts.get_user(member.id))
      refute is_nil(Mosslet.Accounts.get_user(owner.id))

      # The member's personal billing customer + subscription survive.
      surviving = Customers.get_customer_by_source(:user, member.id)
      refute is_nil(surviving)
      assert surviving.id == member_customer.id

      assert Subscriptions.get_active_subscription_by_customer_id(surviving.id)
    end

    test "deletes the org's business circles (no orphaning)" do
      %{owner: owner, org: org} = setup_org()

      # A business circle owned by the org (org_id set). Inserted directly to
      # avoid the full ZK group-create path — we only need a row in the org's
      # circle scope to exercise the teardown loop.
      {:ok, {:ok, circle}} =
        Repo.transaction_on_primary(fn ->
          %Mosslet.Groups.Group{}
          |> Ecto.Changeset.change(%{
            name: "Engineering",
            name_hash: "engineering",
            description: "circle",
            user_id: owner.id,
            org_id: org.id
          })
          |> Repo.insert()
        end)

      assert [%{id: circle_id}] = Groups.list_org_business_circles(org)
      assert circle_id == circle.id

      assert {:ok, summary} = Orgs.delete_org_safely(org, owner, @password)
      assert summary.circles_deleted == 1

      # The circle is truly gone — NOT orphaned as a personal circle.
      assert is_nil(Groups.get_group(circle.id))
    end

    test "enqueues a ZK-safe OrgTeardownJob with id + provider refs only" do
      %{owner: owner, org: org} = setup_org()

      {_customer, subscription} = ensure_org_subscription(org)
      org_customer = Customers.get_customer_by_source(:org, org.id)

      assert {:ok, _summary} = Orgs.delete_org_safely(org, owner, @password)

      assert_enqueued(
        worker: OrgTeardownJob,
        args: %{
          "org_id" => org.id,
          "provider_customer_id" => org_customer.provider_customer_id,
          "provider_subscription_id" => subscription.provider_subscription_id
        }
      )

      # ZK guardrail: the enqueued args carry ONLY ids/provider refs — never the
      # org name, name_hash, keys, emails, or secrets.
      [job] = all_enqueued(worker: OrgTeardownJob)

      assert Map.keys(job.args) |> Enum.sort() ==
               ~w(org_id provider_customer_id provider_subscription_id)

      refute org.name in Map.values(job.args)
    end

    test "enqueues a job with nil provider refs when the org never had billing" do
      %{owner: owner, org: org} = setup_org()

      assert {:ok, _summary} = Orgs.delete_org_safely(org, owner, @password)

      assert_enqueued(
        worker: OrgTeardownJob,
        args: %{
          "org_id" => org.id,
          "provider_customer_id" => nil,
          "provider_subscription_id" => nil
        }
      )
    end
  end

  describe "family org parity" do
    test "safe delete works the same for a family org" do
      %{owner: owner, org: org} = setup_org("family")

      assert {:ok, summary} = Orgs.delete_org_safely(org, owner, @password)
      assert summary.org_id == org.id
      assert is_nil(Orgs.get_org_by_id(org.id))
    end
  end

  describe "OrgTeardownJob.perform/1" do
    test "is a safe no-op when there are no provider refs (never-billed org)" do
      assert :ok =
               perform_job(OrgTeardownJob, %{
                 "org_id" => Ecto.UUID.generate(),
                 "provider_customer_id" => nil,
                 "provider_subscription_id" => nil
               })
    end

    test "rejects malformed args" do
      assert {:error, :invalid_args} = perform_job(OrgTeardownJob, %{"unexpected" => "shape"})
    end
  end
end

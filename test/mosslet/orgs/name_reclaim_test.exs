defmodule Mosslet.Orgs.NameReclaimTest do
  @moduledoc """
  Task #236 — org name/slug RECLAIM engine.

  Verifies the DERIVED lifecycle classification (`Orgs.org_reclaim_state/1`),
  the N+1-free candidate selection (`Orgs.list_reclaimable_orgs/1`), the
  re-validating single-org reclaim (`Orgs.reclaim_org_by_id/1`), and the
  `OrgNameReclaimJob` worker paths.

  Reclaim policy under test:

    * `:pending` (never activated, inert)         -> reclaimed after the window
    * `:protected` (active / fresh trial)         -> NEVER reclaimed
    * `:trial_expired` (trial elapsed, no paid)   -> reclaimed
    * `:lapsed` (was live, now canceled/unpaid)   -> NOT reclaimed (routed to #227)

  ZK guardrail: the engine works only on internal ids/statuses/timestamps.
  """
  use Mosslet.DataCase, async: true
  use Oban.Testing, repo: Mosslet.Repo

  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Orgs
  alias Mosslet.Orgs.Jobs.OrgNameReclaimJob

  defp confirmed_user(seed) do
    email = "#{seed}#{System.unique_integer([:positive])}@example.com"

    user_fixture(%{email: email, password: "hello world hello world!"})
    |> Accounts.confirm_user!()
  end

  defp family_org(user) do
    {:ok, org} =
      Orgs.create_org(user, %{
        "name" => "Org #{System.unique_integer([:positive])}",
        "type" => "family"
      })

    org
  end

  # Creates the org's OWN :org-source billing customer.
  defp org_customer(org) do
    {:ok, customer} =
      Customers.create_customer_for_source(:org, org.id, %{
        email: "billing-#{System.unique_integer([:positive])}@example.com",
        provider: "stripe",
        provider_customer_id: "cus_org_#{System.unique_integer([:positive])}"
      })

    customer
  end

  # Persists a subscription on the org's customer with the given status and
  # trial/period-end timestamp.
  defp org_subscription(customer, status, period_end_at) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    {:ok, subscription} =
      Subscriptions.create_subscription(%{
        status: status,
        plan_id: "family-monthly",
        billing_customer_id: customer.id,
        provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
        provider_subscription_items: [
          %{price_id: "price_family_monthly", product_id: "prod_family", quantity: 1}
        ],
        current_period_start: now,
        current_period_end_at: period_end_at
      })

    subscription
  end

  defp future, do: NaiveDateTime.utc_now() |> NaiveDateTime.add(14, :day)
  defp past, do: NaiveDateTime.utc_now() |> NaiveDateTime.add(-1, :day)

  describe "org_reclaim_state/1" do
    test ":pending for an inert org with no :org customer at all" do
      org = confirmed_user("inert") |> family_org()
      assert Orgs.org_reclaim_state(org) == :pending
    end

    test ":pending for an org customer with no subscription" do
      org = confirmed_user("cust-no-sub") |> family_org()
      _customer = org_customer(org)
      assert Orgs.org_reclaim_state(org) == :pending
    end

    test ":protected for a fresh trialing sub (trial not elapsed)" do
      org = confirmed_user("trialing") |> family_org()
      org |> org_customer() |> org_subscription("trialing", future())
      assert Orgs.org_reclaim_state(org) == :protected
    end

    test ":protected for an active paid sub" do
      org = confirmed_user("active") |> family_org()
      org |> org_customer() |> org_subscription("active", future())
      assert Orgs.org_reclaim_state(org) == :protected
    end

    test ":trial_expired for a trialing sub whose trial period has elapsed" do
      org = confirmed_user("trial-expired") |> family_org()
      org |> org_customer() |> org_subscription("trialing", past())
      assert Orgs.org_reclaim_state(org) == :trial_expired
    end

    test ":lapsed for a canceled sub (routed to #227, not reclaimed here)" do
      org = confirmed_user("lapsed") |> family_org()
      org |> org_customer() |> org_subscription("canceled", past())
      assert Orgs.org_reclaim_state(org) == :lapsed
    end
  end

  describe "list_reclaimable_orgs/1" do
    test "includes inert orgs older than the window, excludes recent inert orgs" do
      old_org = confirmed_user("old-inert") |> family_org()
      recent_org = confirmed_user("recent-inert") |> family_org()

      # With a 0s window everything inert qualifies by age.
      ids = Orgs.list_reclaimable_orgs(older_than_seconds: 0) |> Enum.map(& &1.id)
      assert old_org.id in ids

      # With a long window, a just-created inert org is still protected.
      ids = Orgs.list_reclaimable_orgs(older_than_seconds: 3600) |> Enum.map(& &1.id)
      refute recent_org.id in ids
    end

    test "includes :trial_expired orgs regardless of the age floor" do
      org = confirmed_user("te-listed") |> family_org()
      org |> org_customer() |> org_subscription("trialing", past())

      ids = Orgs.list_reclaimable_orgs(older_than_seconds: 99_999_999) |> Enum.map(& &1.id)
      assert org.id in ids
    end

    test "excludes protected, active, and lapsed orgs" do
      protected = confirmed_user("p") |> family_org()
      protected |> org_customer() |> org_subscription("trialing", future())

      active = confirmed_user("a") |> family_org()
      active |> org_customer() |> org_subscription("active", future())

      lapsed = confirmed_user("l") |> family_org()
      lapsed |> org_customer() |> org_subscription("unpaid", past())

      ids = Orgs.list_reclaimable_orgs(older_than_seconds: 0) |> Enum.map(& &1.id)
      refute protected.id in ids
      refute active.id in ids
      refute lapsed.id in ids
    end
  end

  describe "reclaim_org_by_id/1 (re-validating delete)" do
    test "reclaims an inert org and frees the row" do
      org = confirmed_user("reclaim-inert") |> family_org()

      assert {:ok, :reclaimed} = Orgs.reclaim_org_by_id(org.id)
      assert Orgs.get_org_by_id(org.id) == nil
    end

    test "reclaims a trial-expired org" do
      org = confirmed_user("reclaim-te") |> family_org()
      org |> org_customer() |> org_subscription("trialing", past())

      assert {:ok, :reclaimed} = Orgs.reclaim_org_by_id(org.id)
      assert Orgs.get_org_by_id(org.id) == nil
    end

    test "retains a protected org" do
      org = confirmed_user("retain-protected") |> family_org()
      org |> org_customer() |> org_subscription("trialing", future())

      assert {:ok, :retained} = Orgs.reclaim_org_by_id(org.id)
      refute Orgs.get_org_by_id(org.id) == nil
    end

    test "retains a lapsed org (left for #227)" do
      org = confirmed_user("retain-lapsed") |> family_org()
      org |> org_customer() |> org_subscription("canceled", past())

      assert {:ok, :retained} = Orgs.reclaim_org_by_id(org.id)
      refute Orgs.get_org_by_id(org.id) == nil
    end

    test "is a safe no-op for an already-deleted org" do
      org = confirmed_user("gone") |> family_org()
      {:ok, _} = Orgs.delete_org(org)

      assert {:ok, :retained} = Orgs.reclaim_org_by_id(org.id)
    end
  end

  describe "OrgNameReclaimJob targeted reclaim" do
    test "schedule_session_end_reclaim/2 enqueues a delayed reclaim_org job (org id only)" do
      org = confirmed_user("enqueue") |> family_org()

      assert {:ok, _job} = OrgNameReclaimJob.schedule_session_end_reclaim(org.id, 60)

      assert_enqueued(
        worker: OrgNameReclaimJob,
        args: %{"action" => "reclaim_org", "org_id" => org.id}
      )
    end

    test "perform reclaim_org deletes a still-inert org" do
      org = confirmed_user("perform-inert") |> family_org()

      assert :ok =
               perform_job(OrgNameReclaimJob, %{"action" => "reclaim_org", "org_id" => org.id})

      assert Orgs.get_org_by_id(org.id) == nil
    end

    test "perform reclaim_org no-ops when the org has since activated" do
      org = confirmed_user("perform-activated") |> family_org()
      # Simulate activation between enqueue and run.
      org |> org_customer() |> org_subscription("trialing", future())

      assert :ok =
               perform_job(OrgNameReclaimJob, %{"action" => "reclaim_org", "org_id" => org.id})

      refute Orgs.get_org_by_id(org.id) == nil
    end
  end

  describe "OrgNameReclaimJob backstop sweep" do
    test "reclaims inert + trial-expired orgs, leaves protected/active/lapsed" do
      inert = confirmed_user("sweep-inert") |> family_org()

      trial_expired = confirmed_user("sweep-te") |> family_org()
      trial_expired |> org_customer() |> org_subscription("trialing", past())

      protected = confirmed_user("sweep-protected") |> family_org()
      protected |> org_customer() |> org_subscription("active", future())

      lapsed = confirmed_user("sweep-lapsed") |> family_org()
      lapsed |> org_customer() |> org_subscription("canceled", past())

      assert :ok =
               perform_job(OrgNameReclaimJob, %{
                 "action" => "sweep",
                 "older_than_seconds" => 0
               })

      assert Orgs.get_org_by_id(inert.id) == nil
      assert Orgs.get_org_by_id(trial_expired.id) == nil
      refute Orgs.get_org_by_id(protected.id) == nil
      refute Orgs.get_org_by_id(lapsed.id) == nil
    end
  end
end

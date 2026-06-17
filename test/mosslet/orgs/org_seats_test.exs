defmodule Mosslet.Orgs.OrgSeatsTest do
  @moduledoc """
  Task #247 (Phase B): the owner-only in-app ADD-SEATS flow at the context layer.
  Exercises the guard branches of `Orgs.set_org_seats/2` that DON'T hit Stripe
  (the success path returns 401 in test mode, like the subdomain add-on) plus
  the `Orgs.seat_management_data/1` bounds used to render the stepper.
  """
  use Mosslet.DataCase, async: true

  import Mosslet.AccountsFixtures
  import Mosslet.OrgsFixtures

  alias Mosslet.Orgs

  defp confirmed_user(seed) do
    user_fixture(%{email: "#{seed}#{System.unique_integer([:positive])}@example.com"})
  end

  defp business_org do
    {:ok, org} =
      Orgs.create_org(confirmed_user("seatowner"), %{
        "name" => "Seat Co #{System.unique_integer([:positive])}",
        "type" => "business"
      })

    org
  end

  defp family_org do
    {:ok, org} =
      Orgs.create_org(confirmed_user("famowner"), %{
        "name" => "Fam #{System.unique_integer([:positive])}",
        "type" => "family"
      })

    org
  end

  describe "set_org_seats/2 — guard branches (no Stripe)" do
    test "{:error, :seats_unavailable} when the org has no subscription to adjust" do
      assert {:error, :seats_unavailable} = Orgs.set_org_seats(business_org(), 12)
    end

    test "{:error, :seats_unavailable} when the org's plan is not seat-based" do
      org = business_org()
      # An artificial non-seat plan on the org sub: seat_based_plan?/1 is false,
      # so we bail before any provider call.
      ensure_org_subscription(org, plan_id: "personal-monthly", quantity: 1)

      assert {:error, :seats_unavailable} = Orgs.set_org_seats(org, 12)
    end

    test "{:error, :below_current_usage} when the clamped target is below filled+pending seats" do
      # Family floor is 5 included seats. Subscribe with room for 6 (1 member +
      # 5 pending), fill it, then try to drop to the included floor (5) — which
      # is below the current usage of 6.
      org = family_org()
      ensure_org_subscription(org, plan_id: "family-monthly", quantity: 6)

      for n <- 1..5 do
        {:ok, _} = Orgs.create_invitation(org, %{"sent_to" => "pending#{n}@example.com"})
      end

      assert Orgs.seat_usage(org) == 6
      # clamp_seats floors the request at the 5 included seats; usage (6) exceeds
      # it -> below_current_usage (refuses to strand a filled/pending seat). No
      # Stripe call is reached.
      assert {:error, :below_current_usage} = Orgs.set_org_seats(org, 1)
    end
  end

  describe "seat_management_data/1 — stepper bounds" do
    test "returns cap/used/min/max for an active per-seat org sub" do
      org = business_org()
      ensure_org_subscription(org, plan_id: "business-monthly", quantity: 14)

      data = Orgs.seat_management_data(org)

      assert data.cap == 14
      # Owner is the only member, no pending invites.
      assert data.used == 1
      # min floors at the plan's included seats (10) since usage is below it.
      assert data.min == 10
      assert data.max == 200
    end

    test "min floors at current usage when usage exceeds included seats" do
      org = family_org()
      ensure_org_subscription(org, plan_id: "family-monthly", quantity: 6)

      for n <- 1..5 do
        {:ok, _} = Orgs.create_invitation(org, %{"sent_to" => "fp#{n}@example.com"})
      end

      data = Orgs.seat_management_data(org)
      assert data.used == 6
      assert data.min == 6
      assert data.max == 30
    end

    test "nil when the org has no seat-based subscription" do
      refute Orgs.seat_management_data(business_org())

      org = business_org()
      ensure_org_subscription(org, plan_id: "personal-monthly", quantity: 1)
      refute Orgs.seat_management_data(org)
    end
  end
end

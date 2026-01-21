defmodule MossletWeb.API.BillingControllerTest do
  use MossletWeb.ConnCase, async: true

  import Mosslet.AccountsFixtures

  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions

  setup %{conn: conn} do
    user = user_fixture()
    session_key = "test_session_key"
    {:ok, token} = Mosslet.API.Token.generate(user, session_key)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    {:ok, conn: conn, user: user}
  end

  describe "GET /api/billing/subscription" do
    test "returns no subscription when user has none", %{conn: conn} do
      conn = get(conn, ~p"/api/billing/subscription")

      assert json_response(conn, 200) == %{
               "has_subscription" => false,
               "subscription" => nil,
               "payment_intent" => nil
             }
    end

    test "returns subscription when user has active subscription", %{conn: conn, user: user} do
      {:ok, customer} =
        Customers.create_customer_for_source(
          :user,
          user.id,
          %{
            email: user.email,
            provider: "stripe",
            provider_customer_id: "cus_test_123"
          },
          user,
          "test_session_key"
        )

      {:ok, subscription} =
        Subscriptions.create_subscription(%{
          billing_customer_id: customer.id,
          plan_id: "personal-monthly",
          status: "active",
          provider_subscription_id: "sub_test_123",
          provider_subscription_items: [%{price: "price_test"}],
          current_period_start: NaiveDateTime.utc_now()
        })

      conn = get(conn, ~p"/api/billing/subscription")

      response = json_response(conn, 200)
      assert response["has_subscription"] == true
      assert response["subscription"]["id"] == subscription.id
      assert response["subscription"]["status"] == "active"
      assert response["subscription"]["plan_id"] == "personal-monthly"
    end
  end

  describe "GET /api/billing/products" do
    test "returns available products with mobile IDs", %{conn: conn} do
      conn = get(conn, ~p"/api/billing/products")

      response = json_response(conn, 200)
      assert is_list(response["products"])
    end
  end

  describe "POST /api/billing/apple/validate" do
    test "returns error without transaction_id", %{conn: conn} do
      conn = post(conn, ~p"/api/billing/apple/validate", %{})

      assert json_response(conn, 400) == %{
               "error" => "missing_parameter",
               "message" => "transaction_id is required"
             }
    end
  end

  describe "POST /api/billing/google/validate" do
    test "returns error without required params", %{conn: conn} do
      conn = post(conn, ~p"/api/billing/google/validate", %{})

      assert json_response(conn, 400) == %{
               "error" => "missing_parameter",
               "message" => "product_id and purchase_token are required"
             }
    end
  end

  describe "POST /api/billing/restore" do
    test "returns error without valid platform", %{conn: conn} do
      conn = post(conn, ~p"/api/billing/restore", %{})

      assert json_response(conn, 400) == %{
               "error" => "invalid_request",
               "message" => "platform and transactions/purchases required"
             }
    end

    test "handles apple restore with empty transactions", %{conn: conn} do
      conn = post(conn, ~p"/api/billing/restore", %{"platform" => "apple", "transactions" => []})

      response = json_response(conn, 200)
      assert response["restored"] == 0
      assert response["subscription"] == nil
    end

    test "handles google restore with empty purchases", %{conn: conn} do
      conn = post(conn, ~p"/api/billing/restore", %{"platform" => "google", "purchases" => []})

      response = json_response(conn, 200)
      assert response["restored"] == 0
      assert response["subscription"] == nil
    end
  end
end

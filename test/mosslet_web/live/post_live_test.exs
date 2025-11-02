defmodule MossletWeb.PostLiveTest do
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.TimelineFixtures
  import Mosslet.AccountsFixtures

  # skip these tests as our post_live page is legacy
  @moduletag :skip

  @provider_customer_id "cus_#{Faker.Util.format("%3b%1d%2b%2d%4b%1d%1b")}"
  @provider_latest_charge_id "ch_#{Faker.Util.format("%3b%1d%2b%2d%4b%1d%1b")}"
  @provider_payment_intent_id "pi_#{Faker.Util.format("%3b%1d%2b%2d%4b%1d%1b")}"
  @provider_payment_method_id "pm_#{Faker.Util.format("%3b%1d%2b%2d%4b%1d%1b")}"
  @valid_password "hello world hello world"
  @valid_email Faker.Internet.safe_email()

  describe "Index" do
    setup [:create_user, :create_post]

    test "lists all posts", %{conn: conn, user: user, key: key} do
      {:ok, _index_live, html} =
        conn
        |> log_in_user(user, key)
        |> live(~p"/app/timeline")

      assert html =~ "Timeline"
      assert html =~ "some body"
    end
  end

  defp create_user(_) do
    # Create user that's already confirmed and onboarded
    user =
      user_fixture(%{
        email: @valid_email,
        password: "hello world hello world!"
      })

    # confirm the user
    user = Mosslet.Accounts.confirm_user!(user)

    # update user onboarding
    {:ok, user} = Mosslet.Accounts.update_user_onboarding(user, %{is_onboarded?: true})

    # Get session key for decryption
    key = get_key(user, "hello world hello world!")

    # Update the user name
    {:ok, user} =
      Mosslet.Accounts.update_user_onboarding_profile(user, %{name: "User One"},
        change_name: true,
        key: key,
        user: user
      )

    # Create billing customer and subscription for the first user
    {:ok, customer} = create_billing_customer(user, key)
    {:ok, _payment_intent} = create_payment_intent(customer, user, key)

    # Create the second user
    reverse_user =
      Mosslet.AccountsFixtures.user_fixture(%{
        username: "reverse_group_friend",
        email: "reverse_group_email@example.com",
        password: @valid_password
      })

    r_key = get_key(reverse_user, @valid_password)

    # update the visibility
    {:ok, reverse_user} =
      Mosslet.Accounts.update_user_visibility(reverse_user, %{visibility: :connections},
        key: r_key
      )

    {:ok, reverse_user} =
      Mosslet.Accounts.update_user_onboarding_profile(reverse_user, %{name: "User Two"},
        change_name: true,
        key: r_key,
        user: reverse_user
      )

    # We need to create user_connection for the user
    # the reverse_user id is the user id of the user
    # creating the initial user_connection request
    #
    # the user_id is the recipient_id
    uconn_attrs = %{
      "color" => "rose",
      "temp_label" => "friend",
      "connection_id" => user.connection.id,
      "reverse_user_id" => user.id,
      "selector" => "username",
      "username" => "reverse_group_friend"
    }

    _user_connection =
      Mosslet.UserConnectionFixtures.user_connection_fixture(uconn_attrs,
        user: user,
        reverse_user: reverse_user,
        key: key,
        r_key: r_key,
        confirm?: true
      )

    %{user: user, key: key, customer: customer}
  end

  defp create_billing_customer(user, key) do
    Mosslet.Billing.Customers.create_customer_for_source(
      :user,
      user.id,
      %{
        email: Mosslet.Encrypted.Users.Utils.decrypt_user_data(user.email, user, key),
        provider: "stripe",
        provider_customer_id: @provider_customer_id,
        user_id: user.id
      },
      user,
      key
    )
  end

  defp create_payment_intent(customer, user, key) do
    Mosslet.Billing.PaymentIntents.create_payment_intent!(
      %{
        provider_payment_intent_id: @provider_payment_intent_id,
        provider_customer_id: @provider_customer_id,
        provider_latest_charge_id: @provider_latest_charge_id,
        provider_payment_method_id: @provider_payment_method_id,
        provider_created_at: DateTime.utc_now(),
        amount: 5900,
        amount_received: 5900,
        status: "succeeded",
        billing_customer_id: customer.id
      },
      user,
      key
    )
  end

  defp create_post(%{user: user, key: key, customer: _customer}) do
    post = post_fixture(%{user_id: user.id}, user: user, key: key)
    %{post: post}
  end

  defp get_key(user, password) do
    case Mosslet.Accounts.User.valid_key_hash?(user, password) do
      {:ok, key} -> key
      _ -> raise "Failed to get session key"
    end
  end

  defp log_in_user(conn, user, key) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, Mosslet.Accounts.generate_user_session_token(user))
    |> Plug.Conn.put_session(:key, key)
  end
end

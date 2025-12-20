defmodule Mosslet.Billing.Providers.Behaviour do
  @moduledoc """
  To be implemented by all billing providers.
  """
  @type id :: binary()
  @type user :: struct()
  @type customer :: struct()
  @type plan :: map()
  @type payment_intent :: struct()
  @type subscription :: struct()
  @type source :: :user | :org
  @type source_id :: String.t()
  @type session :: term()
  @type session_key :: binary()

  @callback checkout(user, plan, source, source_id, session_key) ::
              {:ok, customer, session} | {:error, term()}
  @callback change_plan(customer, subscription, plan, user, session_key) ::
              {:ok, session} | {:error, term()}
  @callback checkout_url(session) :: String.t()
  @callback retrieve_charge(id) :: {:ok, term()} | {:error, term()}
  @callback retrieve_payment_intent(id) :: {:ok, term()} | {:error, term()}
  @callback retrieve_product(id) :: {:ok, term()} | {:error, term()}
  @callback payment_intent_adapter() :: module()
  @callback subscription_adapter() :: module()
  @callback get_payment_intent_charge_price(term()) :: String.t() | number()
  @callback get_payment_intent_charge_created(term()) :: String.t() | Calendar.calendar()
  @callback get_subscription_product(term()) :: String.t()
  @callback get_subscription_price(term()) :: String.t() | number()
  @callback get_subscription_cycle(term()) :: String.t()
  @callback get_subscription_next_charge(term()) :: String.t() | Calendar.calendar()
  @callback retrieve_subscription(id) :: {:ok, term()} | {:error, term()}
  @callback cancel_subscription(id) :: {:ok, term()} | {:error, term()}
  @callback cancel_subscription_immediately(id) :: {:ok, term()} | {:error, term()}
  @callback resume_subscription(id) :: {:ok, term()} | {:error, term()}
  @callback sync_subscription(customer, user, session_key) :: :ok
  @callback sync_payment_intent(customer, user, session_key) :: :ok

  defmacro __using__(_) do
    quote do
      @behaviour Mosslet.Billing.Providers.Behaviour

      import Mosslet.Billing.Providers.Behaviour.UrlHelpers
    end
  end
end

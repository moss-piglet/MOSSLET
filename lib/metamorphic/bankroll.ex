defmodule Metamorphic.Bankroll do
  @behaviour Bankroll

  @impl Bankroll
  def customer_display_name(customer) do
    # Need to decrypt
    # customer.email
    customer.stripe_id
  end

  @impl Bankroll
  def can_subscribe_to_plan?(customer, plan) do
    memory_count = Metamorphic.Memories.get_count(customer)


    cond do
      plan[:title] == "Starter" && memory_count > 50 ->
        {:error, "You must compost some Memories first"}

      plan[:title] == "Lite" && memory_count > 500 ->
        {:error, "You must compost some Memories first"}

      plan[:title] == "Plus" && memory_count > 5_000 ->
        {:error, "You must compost some Memories first"}

      plan[:title] == "Pro" && memory_count > 10_000 ->
        {:error, "You must compost some Memories first"}

      plan[:title] == "Pro AI" && memory_count > 50_000 ->
        {:error, "You must compost some Memories first"}

      true ->
        :ok
    end
  end
end

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
        {:error,
         "Woops, you have #{number_to_string(memory_count)} Memories. You must delete some Memories before switching to this plan."}

      plan[:title] == "Lite" && memory_count > 500 ->
        {:error,
         "Woops, you have #{number_to_string(memory_count)} Memories. You must delete some Memories before switching to this plan."}

      plan[:title] == "Plus" && memory_count > 5_000 ->
        {:error,
         "Woops, you have #{number_to_string(memory_count)} Memories. You must delete some Memories before switching to this plan."}

      plan[:title] == "Pro" && memory_count > 10_000 ->
        {:error,
         "Woops, you have #{number_to_string(memory_count)} Memories. You must delete some Memories before switching to this plan."}

      plan[:title] == "Pro AI" && memory_count > 50_000 ->
        {:error,
         "Woops, you have #{number_to_string(memory_count)} Memories. You must delete some Memories before switching to this plan."}

      true ->
        :ok
    end
  end

  defp number_to_string(number) do
    case Metamorphic.Cldr.Number.to_string(number) do
      {:ok, string} ->
        string

      _rest ->
        nil
    end
  end
end

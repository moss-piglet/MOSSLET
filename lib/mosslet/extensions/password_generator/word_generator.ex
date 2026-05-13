defmodule Mosslet.Extensions.PasswordGenerator.WordGenerator do
  alias Mosslet.Extensions.PasswordGenerator.WordRepository

  @moduledoc """
  Module will generate 5 digits (simulating the dice roll) and form a number (i.e. 12345)
  This number will be used to search for the word associated with that number.
  """

  def generate do
    generated_number = generate_number()
    [%{number: _, word: word}] = WordRepository.get_word_by_number(generated_number)
    word
  end

  def generate_number do
    <<a::32, b::32, c::32>> = :crypto.strong_rand_bytes(12)
    :rand.seed(:exs1024s, {a, b, c})
    Enum.reduce(1..5, 0, fn _, sum -> :rand.uniform(6) + sum * 10 end)
  end
end

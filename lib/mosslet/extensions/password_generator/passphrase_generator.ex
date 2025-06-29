defmodule Mosslet.Extensions.PasswordGenerator.PassphraseGenerator do
  alias Mosslet.Extensions.PasswordGenerator.WordGenerator

  @default_words 5
  @default_separator " "
  @moduledoc """
    Module responsible for generating the passphrase based on the diceware.
    Will make use of `Library.WordGenerator`
  """

  def generate_passphrase(number_of_words \\ @default_words, separator \\ @default_separator) do
    1..number_of_words
    |> Enum.map_join(separator, fn _ -> WordGenerator.generate() end)
  end

  def get_default_number_of_words, do: @default_words
  def get_default_separator, do: @default_separator
end

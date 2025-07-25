defmodule Mosslet.Extensions.PasswordGenerator.WordFileLoader do
  @moduledoc """
  Module responsible for retrieval of words used by the diceware generator
  """
  @otp_app Mix.Project.config()[:app]

  @doc """
  Load words from file
  """
  def load_words do
    File.stream!(Application.app_dir(@otp_app, "/priv/dict/eff_large_wordlist.txt"))
    |> Stream.map(&String.trim(&1))
    |> Stream.map(&String.split(&1, "\t"))
    |> Stream.map(fn [a, b] -> %{number: String.to_integer(a), word: b} end)
    |> Enum.to_list()
  end
end

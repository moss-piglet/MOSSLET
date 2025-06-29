defmodule Util do
  @moduledoc """
  A set of utility functions for use all over the project.
  """

  @doc """
  Useful for printing maps onto the page during development. Or passing a map to a hook
  """
  def to_json(obj) do
    Jason.encode!(obj, pretty: true)
  end

  @doc """
  Get a random string of given length.
  Returns a random url safe encoded64 string of the given length.
  Used to generate tokens for the various modules that require unique tokens.
  """
  def random_string(length \\ 10) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64()
    |> binary_part(0, length)
  end

  @doc """
  Get a random numeric string of given length.
  """
  def random_numeric_string(length \\ 10) do
    length
    |> :crypto.strong_rand_bytes()
    |> :crypto.bytes_to_integer()
    |> Integer.to_string()
    |> binary_part(0, length)
  end

  @doc """
  Imitates .compact in Ruby... removes nil values from an array https://ruby-doc.org/core-1.9.3/Array.html#method-i-compact

  ## Examples

      iex> compact([1, 2, nil, 3, nil, 4])
      [1, 2, 3, 4]
  """
  def compact(list), do: Enum.filter(list, &(!is_nil(&1)))

  def email_valid?(email) do
    EmailChecker.valid?(email)
  end

  @doc """
  Evaluates if a value is blank. Returns true if the value is nil, an empty string, or an empty list.

  ## Examples

      iex> blank?(nil)
      true
      iex> blank?("")
      true
      iex> blank?([])
      true
      iex> blank?([1])
      false
      iex> blank?("Hello")
      false
  """

  def blank?(term) do
    Blankable.blank?(term)
  end

  @doc "Opposite of blank?"
  def present?(term) do
    !Blankable.blank?(term)
  end

  @doc "Check if a map has atoms as keys"
  def map_has_atom_keys?(map) do
    map
    |> Map.keys()
    |> List.first()
    |> is_atom()
  end

  @doc """

  ## Examples

      iex> format_money(123456)
      "$1,234.56"
  """
  def format_money(cents, currency \\ "USD") do
    CurrencyFormatter.format(cents, currency)
  end

  @doc "Trim whitespace on either end of a string. Account for nil"
  def trim(str) when is_nil(str), do: str
  def trim(str) when is_binary(str), do: String.trim(str)

  @doc "Useful for when you have an array of strings coming in from a user form"
  def trim_strings_in_array(array) do
    array
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&present?/1)
  end

  @doc """
  ## Examples:

      iex> pluralize("hat", 0)
      "hats"
      iex> pluralize("hat", 1)
      "hat"
      iex> pluralize("hat", 2)
      "hats"
  """
  def pluralize(word, count), do: Inflex.inflect(word, count)

  @doc """
  ## Examples:

      iex> Util.truncate("This is a very long string", 15)
      "This is a ve..."
  """
  def truncate(text, count \\ 10) do
    Mosslet.Extensions.StringExt.truncate(text, length: count)
  end

  @doc """
  ## Examples:

      iex> number_with_delimiter(1000)
      "1,000"
      iex> number_with_delimiter(1000000)
      "1,000,000"
  """
  def number_with_delimiter(i) when is_binary(i), do: number_with_delimiter(String.to_integer(i))

  def number_with_delimiter(i) when is_integer(i) do
    i
    |> Integer.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3, 3, [])
    |> Enum.join(",")
    |> String.reverse()
  end

  @doc """
  For updating a database object in a list of database objects.
  The object must have an ID and exist in the list
  eg. users = Util.replace_object_in_list(users, updated_user)
  """
  def replace_object_in_list(list, object) do
    put_in(
      list,
      [Access.filter(&(&1.id == object.id))],
      object
    )
  end

  def deep_struct_to_map(%{} = map), do: convert(map)

  defp convert(data) when is_struct(data) do
    data |> Map.from_struct() |> convert()
  end

  defp convert(data) when is_map(data) do
    for {key, value} <- data, reduce: %{} do
      acc ->
        case key do
          :__meta__ ->
            acc

          other ->
            Map.put(acc, other, convert(value))
        end
    end
  end

  defp convert(other), do: other

  @doc """
  Converts a Unix timestamp to a naive DateTime.

  ## Examples:

      iex> unix_to_naive_datetime(1600000001)
      ~N[2020-09-13 12:26:41]
  """
  def unix_to_naive_datetime(nil), do: nil

  def unix_to_naive_datetime(datetime_in_seconds) do
    datetime_in_seconds
    |> DateTime.from_unix!()
    |> DateTime.to_naive()
  end

  @doc """
  Conditionally puts a key-value pair into a map, only if the value is not nil.

  ## Examples

      iex> maybe_put(%{}, :name, "John")
      %{name: "John"}

      iex> maybe_put(%{name: "Mary"}, :name, "John")
      %{name: "John"}

      iex> maybe_put(%{name: "John"}, :name, nil)
      %{name: "John"}

  """
  def maybe_put(attrs, _key, nil), do: attrs
  def maybe_put(attrs, key, value), do: Map.put(attrs, key, value)
end

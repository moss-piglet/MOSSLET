defmodule Util.HashId do
  @moduledoc false
  @default_opts [min_length: 10, salt_addition: ""]

  @doc """
  Encode an integer into an unguessable string. Useful if you want to obfuscate an ID in a URL.

  Eg. instead of /users/1, it could be /users/jv51er3x94

  Creating your link path:
      "/users/" <> Util.HashId.encode(user.id, min_length: 10)

  Then in your router:
      "/users/:hashed_user_id"

  Finally, in your controller/live view:
      user_id = Util.HashId.decode(params[:hashed_user_id])

  You could use UUIDs, but these can be too long.

  ## Examples

      iex> HashId.encode(1)
      "jv51er3x94"
      iex> HashId.encode(1, min_length: 20)
      "XbkVwqpE93Br2vOm31ND"
      iex> HashId.encode(1, min_length: 20, salt_addition: "xxx")
      "pXJ7eD83ydOnK2zxvqZR"
  """
  def encode(id, opts \\ []) do
    opts = @default_opts |> Keyword.merge(opts) |> Map.new()
    Hashids.encode(coder(opts.min_length, opts.salt_addition), id)
  end

  def decode(data, opts \\ []) do
    opts = @default_opts |> Keyword.merge(opts) |> Map.new()
    List.first(Hashids.decode!(coder(opts.min_length, opts.salt_addition), data))
  end

  defp coder(min_length, salt_addition) do
    # We use the first 10 characters of the secret_key_base, which should be unique to each deployment.
    # For some reason, if we use the whole secret_key_base, adding salt_addition to the end of it has no effect.
    # We want salt_addition to allow devs to encode/decode with different salts.
    salt =
      String.slice(
        Application.get_env(:mosslet, MossletWeb.Endpoint)[:secret_key_base],
        0..9
      ) <>
        salt_addition

    Hashids.new(
      salt: salt,
      min_len: min_length
    )
  end
end

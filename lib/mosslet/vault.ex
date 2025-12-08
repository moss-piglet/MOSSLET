defmodule Mosslet.Vault do
  @moduledoc """
  Cloak Vault for AES-256-GCM encryption at rest.

  Supports key rotation by maintaining multiple cipher configurations:
  - The `default` cipher is used for new encryptions
  - Retired ciphers are kept for decrypting old data
  - Use `Mosslet.Security.KeyRotation` to migrate data to new keys

  ## Environment Variables

  - `CLOAK_KEY` - Base encryption key (base64 encoded, 32 bytes)
  - `CLOAK_KEY_TAG` - Tag for CLOAK_KEY (default: "AES.GCM.V1")
  - `CLOAK_KEY_NEW` - Optional new key for rotation (becomes default when set)
  - `CLOAK_KEY_NEW_TAG` - Tag for new key (default: "AES.GCM.V2")
  - `CLOAK_KEY_RETIRED` - Optional comma-separated list of additional retired keys
    Format: "tag1:base64key1,tag2:base64key2"

  ## Key Rotation Process (Safe Pattern)

  When you want to rotate keys:

  1. Generate a new 32-byte key: `:crypto.strong_rand_bytes(32) |> Base.encode64()`
  2. Set `CLOAK_KEY_NEW` to the new key and `CLOAK_KEY_NEW_TAG` to a new version
  3. Deploy - the system will:
     - Use `CLOAK_KEY_NEW` for all new encryptions
     - Keep `CLOAK_KEY` available for decrypting existing data
  4. Run the key rotation jobs via `Mosslet.Security.KeyRotation`
  5. Once migration completes:
     - Move `CLOAK_KEY_NEW` value to `CLOAK_KEY`
     - Move `CLOAK_KEY_NEW_TAG` value to `CLOAK_KEY_TAG`
     - Remove `CLOAK_KEY_NEW` and `CLOAK_KEY_NEW_TAG`
     - Optionally add old key to `CLOAK_KEY_RETIRED` if you want to keep it longer

  This pattern ensures you never lose access to your current key during rotation.
  """
  use Cloak.Vault, otp_app: :mosslet

  @impl GenServer
  def init(config) do
    ciphers = build_cipher_chain()
    config = Keyword.put(config, :ciphers, ciphers)
    {:ok, config}
  end

  @doc """
  Returns the tag of the current default cipher (the one used for new encryptions).
  """
  def current_cipher_tag do
    if rotation_in_progress?() do
      System.get_env("CLOAK_KEY_NEW_TAG", "AES.GCM.V2")
    else
      System.get_env("CLOAK_KEY_TAG", "AES.GCM.V1")
    end
  end

  @doc """
  Returns the tag of the base key (CLOAK_KEY).
  """
  def base_cipher_tag do
    System.get_env("CLOAK_KEY_TAG", "AES.GCM.V1")
  end

  @doc """
  Returns all configured cipher tags (default + retired).
  """
  def all_cipher_tags do
    ciphers = build_cipher_chain()

    ciphers
    |> Enum.map(fn
      {:default, {_module, opts}} -> Keyword.get(opts, :tag)
      {name, {_module, opts}} -> Keyword.get(opts, :tag) || to_string(name)
    end)
    |> Enum.uniq()
  end

  @doc """
  Returns true if a key rotation is in progress (CLOAK_KEY_NEW is set).
  """
  def rotation_in_progress? do
    System.get_env("CLOAK_KEY_NEW") not in [nil, ""]
  end

  @doc """
  Returns rotation status information for monitoring.
  """
  def rotation_status do
    retired_keys = parse_retired_keys()

    retired_tags =
      Enum.map(retired_keys, fn {tag_atom, _cipher} ->
        Atom.to_string(tag_atom)
      end)

    %{
      rotation_in_progress: rotation_in_progress?(),
      current_default_tag: current_cipher_tag(),
      base_key_tag: base_cipher_tag(),
      base_key_value: System.get_env("CLOAK_KEY"),
      all_tags: all_cipher_tags(),
      retired_key_count: length(retired_keys),
      retired_tags: retired_tags
    }
  end

  defp build_cipher_chain do
    base_key = decode_env!("CLOAK_KEY")
    base_tag = System.get_env("CLOAK_KEY_TAG", "AES.GCM.V1")

    new_key = System.get_env("CLOAK_KEY_NEW")
    new_tag = System.get_env("CLOAK_KEY_NEW_TAG", "AES.GCM.V2")

    retired_ciphers = parse_retired_keys()

    if new_key not in [nil, ""] do
      decoded_new_key = Base.decode64!(new_key)

      [
        {:default, {Cloak.Ciphers.AES.GCM, tag: new_tag, key: decoded_new_key}},
        {String.to_atom(base_tag), {Cloak.Ciphers.AES.GCM, tag: base_tag, key: base_key}}
        | retired_ciphers
      ]
    else
      [{:default, {Cloak.Ciphers.AES.GCM, tag: base_tag, key: base_key}} | retired_ciphers]
    end
  end

  defp decode_env!(var) do
    var
    |> System.get_env()
    |> Base.decode64!()
  end

  defp parse_retired_keys do
    case System.get_env("CLOAK_KEY_RETIRED") do
      nil ->
        []

      "" ->
        []

      retired_string ->
        retired_string
        |> String.split(",")
        |> Enum.map(&parse_retired_key/1)
        |> Enum.reject(&is_nil/1)
    end
  end

  defp parse_retired_key(key_string) do
    case String.split(key_string, ":", parts: 2) do
      [tag, base64_key] ->
        try do
          key = Base.decode64!(base64_key)
          {String.to_atom(tag), {Cloak.Ciphers.AES.GCM, tag: tag, key: key}}
        rescue
          _ -> nil
        end

      _ ->
        nil
    end
  end
end

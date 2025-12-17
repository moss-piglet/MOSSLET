defmodule Mosslet.Encrypted.Native.HMAC do
  @moduledoc """
  HMAC hashing module for native device cache.

  Uses a device-specific HMAC secret stored in the OS keychain,
  providing deterministic hashing for searchable encrypted fields
  in the local SQLite cache.

  ## Architecture

  ```
  Cloud HMAC:   Encrypted.HMAC uses HMAC_SECRET from env
  Native HMAC:  Encrypted.Native.HMAC uses secret from device keychain
  ```

  ## Usage

  Use this type for searchable hash fields in native cache schemas:

      schema "cached_items" do
        field :resource_type_hash, Mosslet.Encrypted.Native.HMAC
      end
  """
  use Cloak.Ecto.HMAC, otp_app: :mosslet

  alias Mosslet.Platform
  alias Mosslet.Platform.Security

  @impl Cloak.Ecto.HMAC
  def init(config) do
    config =
      Keyword.merge(config,
        algorithm: :sha512,
        secret: get_hmac_secret()
      )

    {:ok, config}
  end

  defp get_hmac_secret do
    if Platform.native?() do
      case Security.get_or_create_hmac_secret() do
        {:ok, secret} -> secret
        {:error, _reason} -> nil
      end
    else
      nil
    end
  end
end

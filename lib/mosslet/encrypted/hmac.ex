defmodule Mosslet.Encrypted.HMAC do
  @moduledoc """
  Cloak.Ecto module for configuring the
  HMAC hashing functionality.
  """
  use Cloak.Ecto.HMAC, otp_app: :mosslet

  @impl Cloak.Ecto.HMAC
  def init(config) do
    config =
      Keyword.merge(config,
        algorithm: :sha512,
        secret: System.get_env("HMAC_SECRET")
      )

    {:ok, config}
  end
end

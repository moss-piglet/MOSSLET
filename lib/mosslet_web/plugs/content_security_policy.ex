defmodule MossletWeb.Plugs.ContentSecurityPolicy do
  @moduledoc false
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    # Generate a random nonce for inline scripts
    nonce = :crypto.strong_rand_bytes(16) |> Base.encode64()

    # Get base CSP and inject nonce
    base_csp = Application.get_env(:mosslet, __MODULE__)[:csp]
    csp_with_nonce = String.replace(base_csp, "script-src ", "script-src 'nonce-#{nonce}' ")

    conn
    |> put_resp_header("content-security-policy", csp_with_nonce)
    |> assign(:csp_nonce, nonce)
  end
end

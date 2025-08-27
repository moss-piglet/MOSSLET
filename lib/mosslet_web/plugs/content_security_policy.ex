defmodule MossletWeb.Plugs.ContentSecurityPolicy do
  @moduledoc false
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    csp = Application.get_env(:mosslet, __MODULE__)[:csp]
    put_resp_header(conn, "content-security-policy", csp)
  end
end

defmodule MossletWeb.Plugs.PlugAttack do
  @moduledoc false
  use PlugAttack
  import Plug.Conn

  @alg :sha3_512
  @minute 60_000
  @week 60_000 * 60 * 24 * 7

  # when hashing the ip
  # hash_ip(@alg, convert_ip(conn.remote_ip)
  # ban_for:  3_600_000 (in milliseconds - 1 hour)

  rule "throttle login requests", conn do
    if conn.method == "GET" and conn.path_info == ["auth", "log_in"] and conn.remote_ip do
      throttle("login:" <> hash_ip(@alg, convert_ip(conn.remote_ip)),
        period: @minute,
        limit: 10,
        storage: {PlugAttack.Storage.Ets, MossletWeb.PlugAttack.Storage}
      )
    end
  end

  rule "throttle register page GETs", conn do
    if conn.method == "GET" and conn.path_info == ["auth", "register"] do
      throttle("register:" <> hash_ip(@alg, convert_ip(conn.remote_ip)),
        period: @minute,
        limit: 20,
        storage: {PlugAttack.Storage.Ets, MossletWeb.PlugAttack.Storage}
      )
    end
  end

  rule "throttle join-group password requests", conn do
    if conn.method == "GET" and "join-password" in conn.path_info and
         conn.remote_ip do
      throttle("login:" <> hash_ip(@alg, convert_ip(conn.remote_ip)),
        period: @minute,
        limit: 10,
        storage: {PlugAttack.Storage.Ets, MossletWeb.PlugAttack.Storage}
      )
    end
  end

  rule "fail2ban on login by email", conn do
    if conn.method == "POST" and conn.path_info == ["auth", "log_in"] and conn.remote_ip do
      fail2ban(hash_ip(@alg, convert_email(conn.params["user"]["email"])),
        period: @minute,
        limit: 50,
        ban_for: @week,
        storage: {PlugAttack.Storage.Ets, MossletWeb.PlugAttack.Storage}
      )
    end
  end

  rule "fail2ban on 2fa by ip", conn do
    if conn.method == "POST" and conn.path_info == ["app", "users", "totp"] and conn.remote_ip do
      fail2ban("2fa:" <> hash_ip(@alg, convert_ip(conn.remote_ip)),
        period: @minute,
        limit: 20,
        ban_for: @week,
        storage: {PlugAttack.Storage.Ets, MossletWeb.PlugAttack.Storage}
      )
    end
  end

  rule "fail2ban on unlock session by ip", conn do
    if conn.method == "POST" and conn.path_info == ["auth", "unlock"] and conn.remote_ip do
      fail2ban("2fa:" <> hash_ip(@alg, convert_ip(conn.remote_ip)),
        period: @minute,
        limit: 20,
        ban_for: @week,
        storage: {PlugAttack.Storage.Ets, MossletWeb.PlugAttack.Storage}
      )
    end
  end

  def allow_action(conn, {:throttle, data}, opts) do
    conn
    |> add_throttling_headers(data)
    |> allow_action(true, opts)
  end

  def allow_action(conn, _data, _opts) do
    conn
  end

  def block_action(conn, {:throttle, data}, opts) do
    conn
    |> add_throttling_headers(data)
    |> block_action(false, opts)
  end

  def block_action(conn, _data, _opts) do
    conn
    |> send_resp(:forbidden, "Forbidden\n")
    # It's important to halt connection once we send a response early
    |> halt
  end

  defp add_throttling_headers(conn, data) do
    # The expires_at value is a unix time in milliseconds, we want to return one
    # in seconds
    reset = div(data[:expires_at], 1_000)

    conn
    |> put_resp_header("x-ratelimit-limit", to_string(data[:limit]))
    |> put_resp_header("x-ratelimit-remaining", to_string(data[:remaining]))
    |> put_resp_header("x-ratelimit-reset", to_string(reset))
  end

  defp hash_ip(alg, ip) do
    ip_secret = Application.get_env(:mosslet, :plug_attack_ip_secret)

    :crypto.mac(:hmac, alg, ip_secret, ip)
  end

  # account for invalid Unicode code point errors
  defp convert_ip(ip) do
    :inet.ntoa(ip) |> to_string()
  end

  defp convert_email(email) do
    email
    |> String.downcase()
  end
end

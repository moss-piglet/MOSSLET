defmodule Mosslet.API.Client do
  @moduledoc """
  HTTP client for desktop/mobile apps to communicate with cloud server.

  This module is used by native apps running elixir-desktop to sync data
  with the Fly.io server. All encryption/decryption happens locally on
  the device, achieving true zero-knowledge operation.

  ## Configuration

  Set the API base URL in config:

      config :mosslet, :api_base_url, "https://mosslet.com"

  ## Usage

      # Authenticate
      {:ok, %{token: token, user: user}} = Mosslet.API.Client.login("email", "password")

      # Sync data
      {:ok, %{posts: posts}} = Mosslet.API.Client.fetch_posts(token, since: last_sync)

      # Create content (already encrypted locally)
      {:ok, post} = Mosslet.API.Client.create_post(token, encrypted_payload)
  """

  require Logger

  @default_timeout 30_000

  def base_url do
    Application.get_env(:mosslet, :api_base_url, "http://localhost:4000")
  end

  def login(email, password) do
    request(:post, "/api/auth/login", %{email: email, password: password})
  end

  def register(user_params) do
    request(:post, "/api/auth/register", %{user: user_params})
  end

  def refresh_token(token) do
    request(:post, "/api/auth/refresh", %{}, auth: token)
  end

  def logout(token) do
    request(:post, "/api/auth/logout", %{}, auth: token)
  end

  def me(token) do
    request(:get, "/api/auth/me", %{}, auth: token)
  end

  def fetch_user(token) do
    request(:get, "/api/sync/user", %{}, auth: token)
  end

  def fetch_posts(token, opts \\ []) do
    params = build_sync_params(opts)
    request(:get, "/api/sync/posts", params, auth: token)
  end

  def fetch_connections(token, opts \\ []) do
    params = build_sync_params(opts)
    request(:get, "/api/sync/connections", params, auth: token)
  end

  def fetch_groups(token, opts \\ []) do
    params = build_sync_params(opts)
    request(:get, "/api/sync/groups", params, auth: token)
  end

  def full_sync(token, opts \\ []) do
    params = build_sync_params(opts)
    request(:get, "/api/sync/full", params, auth: token)
  end

  def create_post(token, encrypted_payload) do
    request(:post, "/api/posts", encrypted_payload, auth: token)
  end

  def update_post(token, post_id, encrypted_payload) do
    request(:put, "/api/posts/#{post_id}", encrypted_payload, auth: token)
  end

  def delete_post(token, post_id) do
    request(:delete, "/api/posts/#{post_id}", %{}, auth: token)
  end

  defp request(method, path, body_or_params, opts \\ []) do
    url = base_url() <> path
    headers = build_headers(opts)
    timeout = opts[:timeout] || @default_timeout

    req_opts = [
      headers: headers,
      receive_timeout: timeout
    ]

    req_opts =
      case method do
        :get ->
          Keyword.put(req_opts, :params, body_or_params)

        _ ->
          Keyword.put(req_opts, :json, body_or_params)
      end

    case apply(Req, method, [url, req_opts]) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, atomize_keys(body)}

      {:ok, %Req.Response{status: status, body: body}} ->
        error = atomize_keys(body)
        Logger.warning("API request failed: #{method} #{path} -> #{status}: #{inspect(error)}")
        {:error, {status, error}}

      {:error, reason} ->
        Logger.error("API request error: #{method} #{path} -> #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_headers(opts) do
    headers = [{"content-type", "application/json"}]

    case opts[:auth] do
      nil -> headers
      token -> [{"authorization", "Bearer #{token}"} | headers]
    end
  end

  defp build_sync_params(opts) do
    params = %{}

    params =
      case opts[:since] do
        nil -> params
        %DateTime{} = dt -> Map.put(params, :since, DateTime.to_iso8601(dt))
        ts when is_binary(ts) -> Map.put(params, :since, ts)
      end

    params =
      case opts[:limit] do
        nil -> params
        limit -> Map.put(params, :limit, limit)
      end

    params
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), atomize_keys(v)}
      {k, v} -> {k, atomize_keys(v)}
    end)
  end

  defp atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end

  defp atomize_keys(value), do: value
end

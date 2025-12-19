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

  # Post operations
  def get_post(token, post_id) do
    request(:get, "/api/posts/#{post_id}", %{}, auth: token)
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

  def get_user_posts(token, user_id) do
    request(:get, "/api/users/#{user_id}/posts", %{}, auth: token)
  end

  def count_all_posts(token) do
    request(:get, "/api/posts/count", %{}, auth: token)
  end

  def post_count(token, user_id, options) do
    params = %{user_id: user_id, options: options}
    request(:get, "/api/posts/user-count", params, auth: token)
  end

  def shared_between_users_post_count(token, user_id, current_user_id) do
    request(
      :get,
      "/api/posts/shared-count",
      %{user_id: user_id, current_user_id: current_user_id}, auth: token)
  end

  def timeline_post_count(token, user_id, options) do
    request(:get, "/api/posts/timeline-count", %{user_id: user_id, options: options}, auth: token)
  end

  def reply_count(token, post_id, options) do
    request(:get, "/api/replies/count", %{post_id: post_id, options: options}, auth: token)
  end

  def public_reply_count(token, post_id, options) do
    request(:get, "/api/replies/public-count", %{post_id: post_id, options: options}, auth: token)
  end

  def group_post_count(token, group_id) do
    request(:get, "/api/groups/#{group_id}/post-count", %{}, auth: token)
  end

  def public_post_count_filtered(token, options) do
    request(:get, "/api/posts/public-count", %{options: options}, auth: token)
  end

  def public_post_count(token, user_id) do
    request(:get, "/api/users/#{user_id}/public-post-count", %{}, auth: token)
  end

  def get_shared_posts(token, user_id) do
    request(:get, "/api/users/#{user_id}/shared-posts", %{}, auth: token)
  end

  # Reply operations
  def get_reply(token, reply_id) do
    request(:get, "/api/replies/#{reply_id}", %{}, auth: token)
  end

  # UserPost operations
  def get_user_post(token, user_post_id) do
    request(:get, "/api/user-posts/#{user_post_id}", %{}, auth: token)
  end

  def get_user_post_by_post_and_user(token, post_id, user_id) do
    request(:get, "/api/user-posts/by-post-user", %{post_id: post_id, user_id: user_id},
      auth: token
    )
  end

  # UserPostReceipt operations
  def get_user_post_receipt(token, receipt_id) do
    request(:get, "/api/user-post-receipts/#{receipt_id}", %{}, auth: token)
  end

  # User account operations
  def update_user_name(token, attrs) do
    request(:put, "/api/users/name", attrs, auth: token)
  end

  def update_user_username(token, attrs) do
    request(:put, "/api/users/username", attrs, auth: token)
  end

  def update_user_profile(token, attrs) do
    request(:put, "/api/users/profile", attrs, auth: token)
  end

  def update_user_visibility(token, visibility) do
    request(:put, "/api/users/visibility", %{visibility: visibility}, auth: token)
  end

  def update_user_password(token, current_password, new_password, password_confirmation) do
    request(
      :put,
      "/api/users/password",
      %{
        current_password: current_password,
        password: new_password,
        password_confirmation: password_confirmation
      },
      auth: token
    )
  end

  def update_user_avatar(token, avatar_url, opts \\ []) do
    request(
      :put,
      "/api/users/avatar",
      %{
        avatar_url: avatar_url,
        delete_avatar: Keyword.get(opts, :delete, false)
      },
      auth: token
    )
  end

  def update_user_notifications(token, enabled) do
    request(:put, "/api/users/notifications", %{notifications: enabled}, auth: token)
  end

  def update_user_onboarding(token, attrs) do
    request(:put, "/api/users/onboarding", attrs, auth: token)
  end

  def delete_user_data(token, password, data) do
    request(:post, "/api/users/delete-data", %{current_password: password, data: data},
      auth: token
    )
  end

  def get_deletable_data(token, data) do
    request(:get, "/api/users/deletable-data", %{data: data}, auth: token)
  end

  def delete_data_records(token, password, data) do
    request(:post, "/api/users/delete-data-records", %{current_password: password, data: data},
      auth: token
    )
  end

  def create_user_profile(token, profile_attrs) do
    request(:post, "/api/users/profile", %{profile: profile_attrs}, auth: token)
  end

  def delete_user_profile(token) do
    request(:delete, "/api/users/profile", %{}, auth: token)
  end

  def update_user_onboarding_profile(token, attrs) do
    request(:put, "/api/users/onboarding-profile", attrs, auth: token)
  end

  def update_user_tokens(token, tokens) do
    request(:put, "/api/users/tokens", %{tokens: tokens}, auth: token)
  end

  def update_user_email_notification_received_at(token, timestamp) do
    request(:put, "/api/users/email-notification-received-at", %{timestamp: timestamp},
      auth: token
    )
  end

  def update_user_reply_notification_received_at(token, timestamp) do
    request(:put, "/api/users/reply-notification-received-at", %{timestamp: timestamp},
      auth: token
    )
  end

  def update_user_replies_seen_at(token, timestamp) do
    request(:put, "/api/users/replies-seen-at", %{timestamp: timestamp}, auth: token)
  end

  def create_visibility_group(token, group_attrs) do
    request(:post, "/api/users/visibility-groups", %{group: group_attrs}, auth: token)
  end

  def update_visibility_group(token, group_id, group_attrs) do
    request(:put, "/api/users/visibility-groups/#{group_id}", %{group: group_attrs}, auth: token)
  end

  def delete_visibility_group(token, group_id) do
    request(:delete, "/api/users/visibility-groups/#{group_id}", %{}, auth: token)
  end

  def update_user_forgot_password(token, forgot_password) do
    request(:put, "/api/users/forgot-password", %{forgot_password: forgot_password}, auth: token)
  end

  def update_user_oban_reset_token_id(token, oban_reset_token_id) do
    request(:put, "/api/users/oban-reset-token-id", %{oban_reset_token_id: oban_reset_token_id},
      auth: token
    )
  end

  def reset_user_password(token, current_password, password, password_confirmation) do
    request(
      :post,
      "/api/users/reset-password",
      %{
        current_password: current_password,
        password: password,
        password_confirmation: password_confirmation
      },
      auth: token
    )
  end

  def block_user(token, user_id, opts \\ []) do
    request(
      :post,
      "/api/users/block",
      %{
        user_id: user_id,
        reason: Keyword.get(opts, :reason),
        note: Keyword.get(opts, :note)
      },
      auth: token
    )
  end

  def unblock_user(token, user_id) do
    request(:delete, "/api/users/block/#{user_id}", %{}, auth: token)
  end

  def list_blocked_users(token) do
    request(:get, "/api/users/blocked", %{}, auth: token)
  end

  # Connection operations
  def list_connections(token, opts \\ []) do
    params = build_sync_params(opts)
    request(:get, "/api/connections", params, auth: token)
  end

  def get_connection(token, id) do
    request(:get, "/api/connections/#{id}", %{}, auth: token)
  end

  def create_connection(token, attrs) do
    request(:post, "/api/connections", %{connection: attrs}, auth: token)
  end

  def update_connection(token, id, attrs) do
    request(:put, "/api/connections/#{id}", %{connection: attrs}, auth: token)
  end

  def update_connection_label(token, id, label, label_hash) do
    request(:put, "/api/connections/#{id}/label", %{label: label, label_hash: label_hash},
      auth: token
    )
  end

  def update_connection_zen(token, id, zen) do
    request(:put, "/api/connections/#{id}/zen", %{zen: zen}, auth: token)
  end

  def update_connection_photos(token, id, photos) do
    request(:put, "/api/connections/#{id}/photos", %{photos: photos}, auth: token)
  end

  def confirm_connection(token, id, attrs \\ %{}) do
    request(:post, "/api/connections/#{id}/confirm", %{connection: attrs}, auth: token)
  end

  def delete_connection(token, id) do
    request(:delete, "/api/connections/#{id}", %{}, auth: token)
  end

  def delete_both_connections(token, id) do
    request(:delete, "/api/connections/#{id}/both", %{}, auth: token)
  end

  def list_arrivals(token) do
    request(:get, "/api/connections/arrivals", %{}, auth: token)
  end

  def totp_status(token) do
    request(:get, "/api/auth/totp/status", %{}, auth: token)
  end

  def setup_totp(token) do
    request(:post, "/api/auth/totp/setup", %{}, auth: token)
  end

  def enable_totp(token, secret, code) do
    request(:post, "/api/auth/totp/enable", %{secret: secret, code: code}, auth: token)
  end

  def disable_totp(token, opts) do
    params =
      cond do
        Keyword.has_key?(opts, :password) -> %{password: opts[:password]}
        Keyword.has_key?(opts, :code) -> %{code: opts[:code]}
        true -> %{}
      end

    request(:post, "/api/auth/totp/disable", params, auth: token)
  end

  def regenerate_backup_codes(token, code) do
    request(:post, "/api/auth/totp/backup-codes/regenerate", %{code: code}, auth: token)
  end

  def login_with_totp(email, password, totp_code) do
    request(:post, "/api/auth/login", %{email: email, password: password, totp_code: totp_code})
  end

  def verify_totp_token(totp_token, code) do
    request(:post, "/api/auth/totp/verify", %{totp_token: totp_token, code: code})
  end

  def request_password_reset(email) do
    request(:post, "/api/auth/password/reset-request", %{email: email})
  end

  def verify_password_reset_token(token) do
    request(:post, "/api/auth/password/verify-token", %{token: token})
  end

  def reset_password_with_token(token, password, password_confirmation) do
    request(:post, "/api/auth/password/reset", %{
      token: token,
      password: password,
      password_confirmation: password_confirmation
    })
  end

  def resend_confirmation_email(email) do
    request(:post, "/api/auth/confirmation/resend", %{email: email})
  end

  def confirm_email_with_token(token) do
    request(:post, "/api/auth/confirmation/confirm", %{token: token})
  end

  def request_email_change(token, email, password) do
    request(:post, "/api/users/email/change-request", %{email: email, current_password: password},
      auth: token
    )
  end

  def confirm_email_change(token, change_token) do
    request(:post, "/api/users/email/change-confirm", %{token: change_token}, auth: token)
  end

  def delete_account(token, password) do
    request(:delete, "/api/users/account", %{current_password: password}, auth: token)
  end

  def delete_all_user_connections(token, user_id) do
    request(:delete, "/api/users/#{user_id}/connections", %{}, auth: token)
  end

  def delete_all_groups(token, user_id) do
    request(:delete, "/api/users/#{user_id}/groups", %{}, auth: token)
  end

  def delete_all_memories(token, user_id) do
    request(:delete, "/api/users/#{user_id}/memories", %{}, auth: token)
  end

  def delete_all_posts(token, user_id) do
    request(:delete, "/api/users/#{user_id}/posts", %{}, auth: token)
  end

  def delete_all_user_memories(token, uconn_id) do
    request(:delete, "/api/connections/#{uconn_id}/memories", %{}, auth: token)
  end

  def delete_all_user_posts(token, uconn_id) do
    request(:delete, "/api/connections/#{uconn_id}/posts", %{}, auth: token)
  end

  def delete_all_remarks(token, user_id) do
    request(:delete, "/api/users/#{user_id}/remarks", %{}, auth: token)
  end

  def delete_all_replies(token, user_id) do
    request(:delete, "/api/users/#{user_id}/replies", %{}, auth: token)
  end

  def delete_all_bookmarks(token, user_id) do
    request(:delete, "/api/users/#{user_id}/bookmarks", %{}, auth: token)
  end

  def cleanup_shared_users_from_posts(token, uconn_user_id, uconn_reverse_user_id) do
    request(
      :post,
      "/api/users/cleanup-shared-users",
      %{type: "posts", user_id: uconn_user_id, reverse_user_id: uconn_reverse_user_id},
      auth: token
    )
  end

  def cleanup_shared_users_from_memories(token, uconn_user_id, uconn_reverse_user_id) do
    request(
      :post,
      "/api/users/cleanup-shared-users",
      %{type: "memories", user_id: uconn_user_id, reverse_user_id: uconn_reverse_user_id},
      auth: token
    )
  end

  def get_all_memories_for_user(token, user_id) do
    request(:get, "/api/users/#{user_id}/all-memories", %{}, auth: token)
  end

  def get_all_posts_for_user(token, user_id) do
    request(:get, "/api/users/#{user_id}/all-posts", %{}, auth: token)
  end

  def get_all_replies_for_user(token, user_id) do
    request(:get, "/api/users/#{user_id}/all-replies", %{}, auth: token)
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

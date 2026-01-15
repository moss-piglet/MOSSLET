defmodule Mosslet.DeepLink do
  @moduledoc """
  Handles deep link URL parsing and route resolution for native apps.

  Deep links allow users to open specific content directly in the native app
  from external sources (emails, notifications, other apps).

  ## Supported URL Schemes

  - Universal Links (iOS): `https://mosslet.com/...`
  - App Links (Android): `https://mosslet.com/...`
  - Custom scheme: `mosslet://...` (fallback)

  ## Route Categories

  - **Content**: Posts, profiles, groups
  - **Actions**: Accept invites, confirm email
  - **Navigation**: Settings, timeline sections
  """

  @type route ::
          {:profile, String.t()}
          | {:post, String.t()}
          | {:group, String.t()}
          | {:group_invite, String.t()}
          | {:connection_invite, String.t()}
          | {:confirm_email, String.t()}
          | {:settings, atom()}
          | {:timeline, atom()}
          | {:journal, atom()}
          | {:home, nil}
          | {:unknown, String.t()}

  @doc """
  Parses a deep link URL and returns the route information.

  ## Examples

      iex> Mosslet.DeepLink.parse("https://mosslet.com/profile/johndoe")
      {:profile, "johndoe"}

      iex> Mosslet.DeepLink.parse("mosslet://app/timeline")
      {:timeline, :home}

      iex> Mosslet.DeepLink.parse("https://mosslet.com/app/journal")
      {:journal, :index}
  """
  @spec parse(String.t()) :: route()
  def parse(url) when is_binary(url) do
    uri = URI.parse(url)
    query = URI.decode_query(uri.query || "")

    path =
      if uri.scheme == "mosslet" do
        case uri.host do
          nil -> uri.path || ""
          "app" -> "/app#{uri.path || ""}"
          host -> "/#{host}#{uri.path || ""}"
        end
      else
        uri.path || ""
      end

    parse_path(path, query)
  end

  defp parse_path("/profile/" <> slug, _query), do: {:profile, slug}

  defp parse_path("/app/posts/" <> id, _query), do: {:post, id}
  defp parse_path("/post/" <> id, _query), do: {:post, id}

  defp parse_path("/app/groups/" <> id, _query), do: {:group, id}
  defp parse_path("/group/" <> id, _query), do: {:group, id}

  defp parse_path("/invite/group/" <> token, _query), do: {:group_invite, token}
  defp parse_path("/invite/connection/" <> token, _query), do: {:connection_invite, token}
  defp parse_path("/invite/" <> token, _query), do: {:connection_invite, token}

  defp parse_path("/users/settings/confirm-email/" <> token, _query), do: {:confirm_email, token}

  defp parse_path("/app/users/edit-details", _query), do: {:settings, :details}
  defp parse_path("/app/users/edit-profile", _query), do: {:settings, :profile}
  defp parse_path("/app/users/edit-email", _query), do: {:settings, :email}
  defp parse_path("/app/users/edit-visibility", _query), do: {:settings, :visibility}
  defp parse_path("/app/users/edit-status", _query), do: {:settings, :status}
  defp parse_path("/app/users/edit-notifications", _query), do: {:settings, :notifications}
  defp parse_path("/app/users/change-password", _query), do: {:settings, :password}
  defp parse_path("/app/users/two-factor-authentication", _query), do: {:settings, :totp}
  defp parse_path("/app/users/manage-data", _query), do: {:settings, :data}
  defp parse_path("/app/users/blocked-users", _query), do: {:settings, :blocked}

  defp parse_path("/app/timeline", _query), do: {:timeline, :home}
  defp parse_path("/app/timeline/connections", _query), do: {:timeline, :connections}
  defp parse_path("/app/timeline/groups", _query), do: {:timeline, :groups}
  defp parse_path("/app/timeline/discover", _query), do: {:timeline, :discover}

  defp parse_path("/app/journal", _query), do: {:journal, :index}
  defp parse_path("/app/journal/new", _query), do: {:journal, :new}
  defp parse_path("/app/journal/books", _query), do: {:journal, :books}

  defp parse_path("/app/connections", _query), do: {:connections, :index}

  defp parse_path("/app" <> _, _query), do: {:home, nil}
  defp parse_path("/", _query), do: {:home, nil}
  defp parse_path("", _query), do: {:home, nil}
  defp parse_path(path, _query), do: {:unknown, path}

  @doc """
  Converts a parsed route back to a path suitable for LiveView navigation.

  ## Examples

      iex> Mosslet.DeepLink.to_path({:profile, "johndoe"})
      "/profile/johndoe"

      iex> Mosslet.DeepLink.to_path({:timeline, :connections})
      "/app/timeline/connections"
  """
  @spec to_path(route()) :: String.t()
  def to_path({:profile, slug}), do: "/profile/#{slug}"
  def to_path({:post, id}), do: "/app/posts/#{id}"
  def to_path({:group, id}), do: "/app/groups/#{id}"
  def to_path({:group_invite, token}), do: "/invite/group/#{token}"
  def to_path({:connection_invite, token}), do: "/invite/#{token}"
  def to_path({:confirm_email, token}), do: "/users/settings/confirm-email/#{token}"
  def to_path({:settings, :details}), do: "/app/users/edit-details"
  def to_path({:settings, :profile}), do: "/app/users/edit-profile"
  def to_path({:settings, :email}), do: "/app/users/edit-email"
  def to_path({:settings, :visibility}), do: "/app/users/edit-visibility"
  def to_path({:settings, :status}), do: "/app/users/edit-status"
  def to_path({:settings, :notifications}), do: "/app/users/edit-notifications"
  def to_path({:settings, :password}), do: "/app/users/change-password"
  def to_path({:settings, :totp}), do: "/app/users/two-factor-authentication"
  def to_path({:settings, :data}), do: "/app/users/manage-data"
  def to_path({:settings, :blocked}), do: "/app/users/blocked-users"
  def to_path({:timeline, :home}), do: "/app/timeline"
  def to_path({:timeline, :connections}), do: "/app/timeline/connections"
  def to_path({:timeline, :groups}), do: "/app/timeline/groups"
  def to_path({:timeline, :discover}), do: "/app/timeline/discover"
  def to_path({:journal, :index}), do: "/app/journal"
  def to_path({:journal, :new}), do: "/app/journal/new"
  def to_path({:journal, :books}), do: "/app/journal/books"
  def to_path({:connections, :index}), do: "/app/connections"
  def to_path({:home, _}), do: "/app/timeline"
  def to_path({:unknown, path}), do: sanitize_path(path)

  defp sanitize_path(path) when is_binary(path) do
    path = String.trim(path)

    cond do
      not String.starts_with?(path, "/") -> "/app/timeline"
      String.contains?(path, "..") -> "/app/timeline"
      String.contains?(path, "//") -> "/app/timeline"
      String.match?(path, ~r/^[a-z]+:/i) -> "/app/timeline"
      true -> path
    end
  end

  defp sanitize_path(_), do: "/app/timeline"

  @doc """
  Checks if a route requires authentication.
  """
  @spec requires_auth?(route()) :: boolean()
  def requires_auth?({:profile, _}), do: false
  def requires_auth?({:confirm_email, _}), do: false
  def requires_auth?({:home, _}), do: false
  def requires_auth?(_), do: true

  @doc """
  Generates a deep link URL for sharing.

  ## Options

  - `:scheme` - URL scheme (`:https` or `:custom`). Defaults to `:https`.
  - `:host` - Host for HTTPS URLs. Defaults to "mosslet.com".

  ## Examples

      iex> Mosslet.DeepLink.generate({:profile, "johndoe"})
      "https://mosslet.com/profile/johndoe"

      iex> Mosslet.DeepLink.generate({:post, "abc123"}, scheme: :custom)
      "mosslet://app/posts/abc123"
  """
  @spec generate(route(), keyword()) :: String.t()
  def generate(route, opts \\ []) do
    scheme = Keyword.get(opts, :scheme, :https)
    host = Keyword.get(opts, :host, "mosslet.com")
    path = to_path(route)

    case scheme do
      :https -> "https://#{host}#{path}"
      :custom -> "mosslet:/#{path}"
    end
  end
end

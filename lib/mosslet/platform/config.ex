defmodule Mosslet.Platform.Config do
  @moduledoc """
  Platform-specific configuration helpers.

  Provides runtime configuration that varies based on the deployment platform
  (web server vs native desktop/mobile app).
  """

  alias Mosslet.Platform

  @secret_key_bytes 64
  @salt_bytes 16

  @doc """
  Returns the Ecto repo module to use for the current platform.

  - Web: `Mosslet.Repo` (Postgres via Fly.io)
  - Native: `Mosslet.Repo.SQLite` (local SQLite)
  """
  @spec repo() :: module()
  def repo do
    if Platform.native?() do
      Mosslet.Repo.SQLite
    else
      Mosslet.Repo
    end
  end

  @doc """
  Returns the database path for SQLite (native apps only).
  """
  @spec sqlite_database_path() :: String.t()
  def sqlite_database_path do
    data_dir = data_directory()
    Path.join(data_dir, "mosslet.db")
  end

  @doc """
  Returns the platform-specific data directory for persistent storage.

  Can be overridden with MOSSLET_DATA_DIR environment variable (useful for Docker).

  - macOS: ~/Library/Application Support/Mosslet
  - Windows: %APPDATA%/Mosslet
  - Linux: ~/.local/share/mosslet
  - iOS: App's Documents directory
  - Android: App's internal storage
  """
  @spec data_directory() :: String.t()
  def data_directory do
    case System.get_env("MOSSLET_DATA_DIR") do
      nil -> platform_data_directory()
      dir -> dir
    end
  end

  defp platform_data_directory do
    case Platform.type() do
      :macos ->
        Path.join([System.user_home!(), "Library", "Application Support", "Mosslet"])

      :windows ->
        Path.join([System.get_env("APPDATA", System.user_home!()), "Mosslet"])

      :linux ->
        Path.join([System.user_home!(), ".local", "share", "mosslet"])

      :ios ->
        if Code.ensure_loaded?(Desktop.OS) do
          apply(Desktop.OS, :home, [])
        else
          System.tmp_dir!()
        end

      :android ->
        if Code.ensure_loaded?(Desktop.OS) do
          apply(Desktop.OS, :home, [])
        else
          System.tmp_dir!()
        end

      :web ->
        System.tmp_dir!()
    end
  end

  @doc """
  Ensures the data directory exists.
  """
  @spec ensure_data_directory!() :: :ok
  def ensure_data_directory! do
    dir = data_directory()
    File.mkdir_p!(dir)
    :ok
  end

  @doc """
  Returns the sync API base URL for native apps to communicate with the server.
  """
  @spec sync_api_url() :: String.t()
  def sync_api_url do
    Application.get_env(:mosslet, :sync_api_url, "https://mosslet.com/api/sync")
  end

  @doc """
  Returns configuration for the Phoenix Endpoint based on platform.
  """
  @spec endpoint_config() :: keyword()
  def endpoint_config do
    if Platform.native?() do
      [
        http: [port: 0],
        server: true,
        secret_key_base: generate_secret(),
        live_view: [signing_salt: generate_salt()]
      ]
    else
      Application.get_env(:mosslet, MossletWeb.Endpoint, [])
    end
  end

  @doc """
  Returns the list of children for the supervision tree based on platform.
  """
  @spec supervision_children() :: [Supervisor.child_spec()]
  def supervision_children do
    common_children() ++ platform_specific_children()
  end

  defp common_children do
    [
      MossletWeb.Telemetry,
      {Phoenix.PubSub, name: Mosslet.PubSub},
      MossletWeb.Presence,
      {Task.Supervisor, name: Mosslet.BackgroundTask},
      {Finch, name: Mosslet.Finch},
      ExMarcel.TableWrapper,
      Mosslet.Extensions.AvatarProcessor,
      Mosslet.Extensions.MemoryProcessor
    ]
  end

  defp platform_specific_children do
    if Platform.native?() do
      native_children()
    else
      web_children()
    end
  end

  defp native_children do
    [
      Mosslet.Repo.SQLite
    ]
  end

  defp web_children do
    [
      {Fly.RPC, []},
      Mosslet.Repo.Local,
      {Fly.Postgres.LSN.Supervisor, repo: Mosslet.Repo.Local},
      Mosslet.Vault,
      {DNSCluster, query: Application.get_env(:mosslet, :dns_cluster_query) || :ignore},
      Mosslet.Extensions.URLPreviewServer,
      Mosslet.Timeline.Performance.TimelineCache,
      Mosslet.Notifications.EmailNotificationsProcessor,
      {Mosslet.Notifications.EmailNotificationsGenServer, []},
      {Mosslet.Notifications.ReplyNotificationsGenServer, []},
      {Mosslet.Timeline.Performance.TimelineGenServer, []},
      {Task.Supervisor, name: Mosslet.StorjTask},
      {PlugAttack.Storage.Ets, name: MossletWeb.PlugAttack.Storage, clean_period: 3_600_000},
      Mosslet.Security.BotDefense,
      Mosslet.Security.BotDetector,
      {Mosslet.Extensions.PasswordGenerator.WordRepository, %{}}
    ]
  end

  @doc """
  Generates a cryptographically secure secret key for the local Phoenix endpoint.
  Uses enacl for consistency with the rest of the encryption system.
  """
  @spec generate_secret() :: String.t()
  def generate_secret do
    :enacl.randombytes(@secret_key_bytes) |> Base.encode64()
  end

  @doc """
  Generates a cryptographically secure salt for LiveView signing.
  Uses enacl for consistency with the rest of the encryption system.
  """
  @spec generate_salt() :: String.t()
  def generate_salt do
    :enacl.randombytes(@salt_bytes) |> Base.encode64()
  end
end

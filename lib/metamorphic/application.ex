defmodule Metamorphic.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Logger.add_backend(Sentry.LoggerBackend)
    topologies = Application.get_env(:libcluster, :topologies) || []

    children = [
      # Start the RPC server
      {Fly.RPC, []},
      # Start the Ecto repository
      Metamorphic.Repo.Local,
      # Start the tracker after your DB.
      {Fly.Postgres.LSN.Supervisor, repo: Metamorphic.Repo.Local},
      # Start the Cloak vault.
      Metamorphic.Vault,
      # Start Oban supervision.
      {Oban, Application.fetch_env!(:metamorphic, Oban)},
      # Start the Telemetry supervisor
      MetamorphicWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Metamorphic.PubSub},
      # Start Finch
      {Finch, name: Metamorphic.Finch},
      # Start OpenAI Finch
      {Finch, name: Metamorphic.OpenAIFinch},
      # Start libcluster for clustering
      {Cluster.Supervisor, [topologies, [name: Metamorphic.ClusterSupervisor]]},
      # Start ExMarcel's mime type dictionary storage
      ExMarcel.TableWrapper,
      # Start the ETS AvatarProcessor
      Metamorphic.Extensions.AvatarProcessor,
      # Start the ETS MemoryProcessor
      Metamorphic.Extensions.MemoryProcessor,
      # Start the Storj Task Supervisor,
      {Task.Supervisor, name: Metamorphic.StorjTask},
      # Start the Endpoint (http/https)
      MetamorphicWeb.Endpoint
      # Start a worker by calling: Metamorphic.Worker.start_link(arg)
      # {Metamorphic.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Metamorphic.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MetamorphicWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

defmodule Metamorphic.MixProject do
  use Mix.Project

  def project do
    [
      app: :metamorphic,
      version: "0.3.20",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Metamorphic.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:abacus, "~> 2.0.0"},
      {:argon2_elixir, "~> 3.0"},
      {:cloak, "~> 1.1"},
      {:cloak_ecto, "~> 1.2"},
      {:earmark, "~> 1.4"},
      {:ecto_sql, "~> 3.10"},
      {:enacl, "~> 1.2"},
      {:esbuild, "~> 0.7", runtime: Mix.env() == :dev},
      {:ex_aws, "~> 2.4"},
      {:ex_aws_s3, "~> 2.4"},
      {:ex_cldr, "~> 2.37"},
      {:ex_cldr_dates_times, "~> 2.0"},
      {:ex_marcel, "~> 0.1.0"},
      {:finch, "~> 0.16"},
      {:floki, ">= 0.30.0", only: :test},
      {:fly_postgres, "~> 0.3.2"},
      {:gettext, "~> 0.20"},
      {:hackney, "~> 1.18"},
      {:image, "~> 0.36.2"},
      {:jason, "~> 1.4"},
      {:langchain, github: "brainlid/langchain", override: true},
      {:libcluster, "~> 3.3"},
      {:nimble_totp, "~> 1.0"},
      {:oban, "~> 2.15"},
      {:phoenix, "~> 1.7.7"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20.0"},
      {:plug_canonical_host, "~> 2.0"},
      {:plug_cowboy, "~> 2.5"},
      {:postgrex, ">= 0.0.0"},
      {:req, "<= 0.3.10"},
      {:sentry, "~> 8.0"},
      {:slugify, "~> 1.3"},
      {:stripity_stripe, "~> 3.0"},
      {:sweet_xml, "~> 0.6"},
      {:swoosh, "~> 1.3"},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:tzdata, "~> 1.1"},
      {:yaml_elixir, "~> 2.9.0"},
      {:zxcvbn, "~> 0.1.3"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end

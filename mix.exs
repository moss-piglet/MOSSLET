defmodule Mosslet.MixProject do
  use Mix.Project

  @version "0.13.0"

  def project do
    [
      app: :mosslet,
      version: @version,
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      dialyzer: [
        plt_core_path: "priv/plts/core.plt",
        plt_file: {:no_warn, "priv/plts/project.plt"},
        plt_add_apps: [:ex_unit]
      ]
    ]
  end

  def application do
    [
      mod: {Mosslet.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"] ++ native_paths()
  defp elixirc_paths(_), do: ["lib"] ++ native_paths()

  defp native_paths do
    if Mix.target() == :native, do: ["lib_native"], else: []
  end

  defp deps do
    shared_deps() ++ target_deps(Mix.target())
  end

  defp target_deps(:native) do
    [
      {:desktop, "~> 1.5"},
      {:ecto_sqlite3, "~> 0.22.0"}
    ]
  end

  defp target_deps(_other) do
    if Mix.env() == :test do
      [{:desktop, "~> 1.5"}]
    else
      []
    end
  end

  defp shared_deps do
    [
      {:a11y_audit, "~> 0.2.3", only: :test},
      {:abacus, "~> 2.1"},
      {:argon2_elixir, "~> 4.0"},
      {:axon, "~> 0.7.0"},
      {:bandit, "~> 1.0"},
      {:blankable, "~> 1.0.0"},
      {:broadway, "~> 1.1"},
      {:bumblebee, "~> 0.6"},
      {:cloak, "~> 1.1"},
      {:cloak_ecto, "~> 1.2"},
      {:cors_plug, "~> 3.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:currency_formatter, "~> 0.4"},
      {:decimal, "~> 2.3"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:dns_cluster, "~> 0.1.3"},
      {:earmark, "~> 1.4"},
      {:ecto_sql, "~> 3.12"},
      {:email_checker, "~> 0.2.4"},
      {:enacl, github: "aeternity/enacl"},
      {:eqrcode, "~> 0.1.10"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:ex_aws, "~> 2.4"},
      {:ex_aws_s3, "~> 2.4"},
      {:ex_cldr, "~> 2.37"},
      {:ex_cldr_dates_times, "~> 2.0"},
      {:exla, "~> 0.9.2"},
      {:expletive, "~> 0.1.5"},
      {:exvcr, "~> 0.15", only: :test},
      {:ex_marcel, "~> 0.1.0"},
      {:faker, "~> 0.18", only: [:test, :dev]},
      {:floki, ">= 0.30.0"},
      {:flop, "~> 0.20"},
      {:fly_postgres, "~> 0.3.2"},
      {:friendlyid, "~> 0.2.0"},
      {:gen_smtp, "~> 1.2"},
      {:gettext, "~> 0.20"},
      {:hackney, "~> 1.18"},
      {:hashids, "~> 2.0"},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.5",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:html_sanitize_ex, "~> 1.4"},
      {:human_name, "~> 0.4.3"},
      {:image, "~> 0.59.0"},
      {:inflex, "~> 2.1.0"},
      {:jason, "~> 1.4"},
      {:langchain, "~> 0.3.3"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:live_select, "~> 1.4"},
      {:mimic, "~> 1.7", only: :test},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:money, "~> 1.12.4"},
      {:nimble_totp, "~> 1.0"},
      {:nx, "~> 0.9"},
      {:oban, "~> 2.17"},
      {:oban_web, "~> 2.11"},
      {:oban_met, "~> 1.0"},
      {:petal_components, "~> 3.0"},
      {:phoenix, "~> 1.8"},
      {:phoenix_ecto, "~> 4.6"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_swoosh, "~> 1.0"},
      {:plug_attack, "~> 0.4.3"},
      {:plug_canonical_host, "~> 2.0"},
      {:plug_cowboy, "~> 2.5"},
      {:postgrex, ">= 0.0.0"},
      {:premailex, "~> 0.3.0"},
      {:query_builder, "~> 1.0"},
      {:remote_ip, "~> 1.0"},
      {:req, "~> 0.5"},
      {:req_llm, "~> 1.2"},
      {:safeurl, "~> 1.0"},
      {:sentry, "~> 8.0"},
      {:sizeable, "~> 1.0"},
      {:slugify, "~> 1.3"},
      {:sobelow, "~> 0.14.1", only: [:dev, :test], runtime: false},
      {:stripity_stripe, "~> 3.1"},
      {:sweet_xml, "~> 0.6"},
      {:swoosh, "~> 1.3"},
      {:tailwind, "~> 0.3.0", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:tesla, "~> 1.7.0"},
      {:tidewave, "~> 0.5", only: :dev},
      {:timex, "~> 3.7", override: true},
      {:typed_ecto_schema, "~> 0.4.1"},
      {:tzdata, "~> 1.1"},
      {:ueberauth, "<= 0.10.5 or ~> 0.10.7"},
      {:ueberauth_google, "~> 0.10"},
      {:ueberauth_github, "~> 0.7"},
      {:wallaby, "~> 0.30", runtime: false, only: :test},
      {:yaml_elixir, "~> 2.9.0"},
      {:zxcvbn, "~> 0.3.0"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["esbuild default", "ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"],
      precommit: ["compile --warning-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end

defmodule MossletWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use MossletWeb, :controller
      use MossletWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets favicon favicon.ico fonts images robots.txt uploads .well-known)

  def router do
    quote do
      use Phoenix.Router, helpers: true

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: MossletWeb.Layouts]

      use Gettext, backend: MossletWeb.Gettext
      import Phoenix.Component, only: [to_form: 2]
      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def view do
    quote do
      use Phoenix.Component, global_prefixes: ~w(x-)

      use Phoenix.View,
        root: "lib/mosslet_web/templates",
        namespace: MossletWeb

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  def component do
    quote do
      use Phoenix.Component, global_prefixes: ~w(x-)

      unquote(html_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {MossletWeb.Layouts, :app},
        global_prefixes: ~w(x-)

      on_mount({MossletWeb.UserOnMountHooks, :maybe_assign_user})
      on_mount(MossletWeb.RestoreLocaleHook)
      on_mount(MossletWeb.AllowEctoSandboxHook)
      on_mount({MossletWeb.ViewSetupHook, :reset_page_title})

      def stream_batch_insert(socket, key, items, opts \\ %{}) do
        items =
          if opts[:at] == 0 do
            Enum.reverse(items)
          else
            items
          end

        items
        |> Enum.reduce(socket, fn item, socket ->
          stream_insert(socket, key, item, opts)
        end)
      end

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent, global_prefixes: ~w(x-)

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component, global_prefixes: ~w(x-)

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # HTML escaping functionality
      # Core UI components and translation
      use PetalComponents
      use MossletComponents

      use Gettext, backend: MossletWeb.Gettext
      import MossletWeb.CoreComponents
      import MossletWeb.DesignSystem
      import MossletWeb.Helpers
      import MossletWeb.Helpers.StatusHelpers
      import MossletWeb.Helpers.StatusHelpers
      import Phoenix.HTML

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      import MossletWeb.Components.MossletAuthLayout

      # Route Helpers
      alias MossletWeb.Router.Helpers, as: Routes
      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: MossletWeb.Endpoint,
        router: MossletWeb.Router,
        statics: MossletWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end

defmodule MossletWeb.Plugs.OrgSubdomain do
  @moduledoc """
  Subdomain-aware host plug (Task #240, Phase B, slice B).

  Resolves the request host's leading label (`acmebiz` in `acmebiz.mosslet.com`)
  to an `Org` via the non-raising `Mosslet.Orgs.get_org_by_subdomain/1` and, when
  matched, tags the connection with `conn.assigns[:subdomain_org]` plus
  `conn.assigns[:subdomain_org_live?]`.

  This plug ONLY resolves and tags — it NEVER authorizes. The subdomain hostname
  label is NON-SENSITIVE plaintext (it is published in the org's branded URL), so
  it is safe to read, route, and log on in the clear. Authorization is enforced
  downstream by the existing membership gate (`current_scope` +
  `Mosslet.Orgs.get_org!/2`, which is `Ecto.assoc(:orgs)`-scoped): resolving an
  org from the host does NOT grant access. A non-member hitting
  `acmebiz.mosslet.com` is still bounced.

  ## Resolve vs. serve (Task #240 / #243, slice D)

  The custom subdomain is a PAID add-on. The plug resolves the org regardless,
  but `:subdomain_org_live?` (= `Mosslet.Orgs.subdomain_live?/1`) tells downstream
  surfaces (e.g. org-branded sign-in) whether the org currently carries the
  add-on entitlement. An org whose add-on has lapsed keeps its reserved
  `subdomain` row but is "resolve-but-don't-serve": `:subdomain_org` is still set,
  `:subdomain_org_live?` is `false`, and branding is NOT shown. Server-
  authoritative and re-evaluated on every request (each HTTP render re-runs this
  plug), so loss of the add-on takes effect immediately.

  Placed in the `:browser` pipeline after `:fetch_current_scope` so downstream
  surfaces can prefer the resolved org while still running the membership check.

  The base host (the apex the subdomain hangs off, e.g. `mosslet.com` in prod,
  `localhost` in dev) is derived from the `:canonical_host` config. When no
  canonical host is configured (e.g. plain test runs), the plug is a no-op.
  """
  @behaviour Plug

  import Plug.Conn

  alias Mosslet.Orgs
  alias Mosslet.Orgs.Org

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case subdomain_label(conn.host, base_host()) do
      {:ok, label} ->
        case Orgs.get_org_by_subdomain(label) do
          %Org{} = org ->
            conn
            |> assign(:subdomain_org, org)
            |> assign(:subdomain_org_live?, Orgs.subdomain_live?(org))

          nil ->
            conn
        end

      :none ->
        conn
    end
  end

  @doc """
  Extracts a single, non-reserved subdomain label from `host` relative to
  `base_host`.

  Returns `{:ok, label}` only for `<label>.<base_host>` where `label` is a single
  hostname label (no embedded dots) that is not in the reserved denylist. Returns
  `:none` for the apex (`base_host` itself), foreign hosts, multi-level labels
  (`a.b.<base_host>`), and reserved labels (`www`, `app`, `api`, …).
  """
  def subdomain_label(host, base_host)
      when is_binary(host) and is_binary(base_host) and base_host != "" do
    suffix = "." <> base_host

    if String.ends_with?(host, suffix) do
      label = String.replace_suffix(host, suffix, "")

      cond do
        label == "" -> :none
        String.contains?(label, ".") -> :none
        Org.reserved_subdomain?(label) -> :none
        true -> {:ok, label}
      end
    else
      :none
    end
  end

  def subdomain_label(_host, _base_host), do: :none

  defp base_host do
    Application.get_env(:mosslet, :canonical_host)
  end
end

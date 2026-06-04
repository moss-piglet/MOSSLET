defmodule Mosslet.Orgs.OrgSeeder do
  @moduledoc """
  Generates dummy orgs for the development environment.
  """
  alias Mosslet.Orgs

  def random_org(user, attrs \\ %{}) do
    attrs = Map.merge(random_org_attributes(), attrs)
    {:ok, org} = Orgs.create_org(user, attrs)
    org
  end

  def random_org_attributes do
    %{
      # NOTE: Faker is temporarily disabled (see mix.exs) — Faker 0.18 emits
      # invalid Unicode that fails to compile under Elixir 1.20. Restore
      # `Faker.Company.name()` once an updated release is available.
      # name: Faker.Company.name()
      name: "Org #{System.unique_integer([:positive])}"
    }
  end
end

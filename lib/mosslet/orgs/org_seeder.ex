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
      name: Faker.Company.name()
    }
  end
end

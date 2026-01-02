defmodule Mosslet.OrgsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Mosslet.Orgs` context.
  """

  alias Mosslet.Orgs

  def unique_org_name, do: "Org #{System.unique_integer([:positive])}"
  def unique_org_slug, do: "org-#{System.unique_integer([:positive])}"

  def valid_org_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => unique_org_name(),
      "slug" => unique_org_slug()
    })
  end

  @doc """
  Generate an organization for a user.
  """
  def org_fixture(user, attrs \\ %{}) do
    attrs = valid_org_attributes(attrs)

    {:ok, org} = Orgs.create_org(user, attrs)

    org
  end
end

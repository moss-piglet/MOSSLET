ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Mosslet.Repo.Local, :manual)
# Configure Wallaby and set base url for tests
{:ok, _} = Application.ensure_all_started(:wallaby)
Application.put_env(:wallaby, :base_url, MossletWeb.Endpoint.url())

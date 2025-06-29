defmodule MossletWeb.Presence do
  @moduledoc false
  use Phoenix.Presence,
    otp_app: :mosslet,
    pubsub_server: Mosslet.PubSub
end

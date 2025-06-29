defmodule Mosslet.Slack do
  @moduledoc """

  Install instructions:
  1. Create a new app at https://api.slack.com and use a manifest
  2. Copy manifest below and change the TODO's

  _metadata:
  major_version: 1
  minor_version: 1
  display_information:
    name: TODO
  features:
    app_home:
      home_tab_enabled: false
      messages_tab_enabled: true
      messages_tab_read_only_enabled: true
    bot_user:
      display_name: TODO
      always_online: false
  oauth_config:
    scopes:
      bot:
        - channels:join
        - channels:read
        - chat:write
        - chat:write.public
  settings:
    org_deploy_enabled: false
    socket_mode_enabled: false
    token_rotation_enabled: false

  3. Click "Install into workspace"
  4. Add SLACK_OAUTH_TOKEN to your environment variables (get it from "OAuth and Permissions" section)
  5. Create the channel in Slack that you want your notifications to go to (if it doesn't already exist)
  6. Run `iex -S mix phx.server` and then `Mosslet.Slack.read_channels`
  7. Get the channel ID of the channel you want to post to. Put it in a new environment variable SLACK_CHANNEL_ID
  8. Run Mosslet.Slack.message("Hello world") to test it out!
  """
  use Tesla

  require Logger

  plug Tesla.Middleware.BaseUrl, "https://slack.com/api"

  plug Tesla.Middleware.Headers, [
    {"Authorization", "Bearer #{System.get_env("SLACK_OAUTH_TOKEN")}"}
  ]

  plug Tesla.Middleware.JSON

  def read_channels do
    {:ok, response} = get("/conversations.list")

    case response.body do
      %{"ok" => true} ->
        Enum.map(response.body["channels"], &[&1["id"], &1["name"]])

      %{"ok" => false} = body ->
        Logger.error(body["error"])
    end
  end

  def join_channel do
    post("/conversations.join", %{
      name: "app-notifications"
    })
  end

  # Posts a slack message in a background task so it doesn't slow down the current process.
  def message(msg) do
    slack_channel_id = System.get_env("SLACK_CHANNEL_ID")

    if slack_channel_id do
      send_slack_message(slack_channel_id, msg)
    else
      Logger.info("Slack not setup. Skipping message: #{msg}")
    end
  end

  defp send_slack_message(channel_id, msg) do
    Mosslet.BackgroundTask.run(fn ->
      post_message(channel_id, msg)
    end)
  end

  defp post_message(channel_id, msg) do
    case post("/chat.postMessage", %{
           channel: channel_id,
           text: msg,
           unfurl_links: false,
           unfurl_media: false
         }) do
      {:ok, _} ->
        Logger.info("Slack message sent: #{msg}")
    end
  end
end

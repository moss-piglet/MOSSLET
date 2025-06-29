defmodule Mosslet.MailBluster do
  @moduledoc """
  This module allows you to sync your users with MailBluster.
  eg. if user.is_subscribed_to_marketing_notifications then they should be synced with MailBluster
  This allows you to send mass emails to your subscribed users.

  When a user unsubs we obviously want user.is_subscribed_to_marketing_notifications to be set to false.
  For this to work ensure that in your MailBluster settings the unsubscribe URL is set to https://YOUR_DOMAIN/unsubscribe/mailbluster?email=%e
  That way, when they click "Unsubscribe" in their emails, they get redirected to your route and that will set user.is_subscribed_to_marketing_notifications to false for you (see UserSettingsController.unsubscribe_from_mailbluster/2).
  """
  use Tesla

  require Logger

  plug Tesla.Middleware.BaseUrl, "https://api.mailbluster.com/api"
  plug Tesla.Middleware.Headers, [{"Authorization", System.get_env("MAIL_BLUSTER_API_KEY")}]
  plug Tesla.Middleware.JSON

  def sync_user_async(user, current_mail_bluster_email \\ nil) do
    if System.get_env("MAIL_BLUSTER_API_KEY") do
      Mosslet.BackgroundTask.run(fn ->
        sync_user(user, current_mail_bluster_email)
      end)
    else
      Logger.info("MAIL_BLUSTER_API_KEY not set. Not syncing with MailBluster")
    end
  end

  def sync_all_users_async do
    mail_bluster_api_key = System.get_env("MAIL_BLUSTER_API_KEY")

    if mail_bluster_api_key do
      start_background_sync()
    else
      Logger.info("MAIL_BLUSTER_API_KEY not set. Not syncing with MailBluster")
    end
  end

  defp start_background_sync do
    Mosslet.BackgroundTask.run(fn ->
      sync_users()
    end)
  end

  defp sync_users do
    Mosslet.Accounts.User
    |> Mosslet.Repo.all()
    |> Enum.each(&sync_user_and_wait/1)
  end

  defp sync_user_and_wait(user) do
    sync_user(user)
    # The API rate limit is 3 requests/second. sync_user takes up two requests (get & add/update)
    :timer.sleep(1000)
  end

  def sync_user(user, current_mail_bluster_email \\ nil) do
    Logger.info("Syncing user with MailBluster")

    case get_user(user, current_mail_bluster_email) do
      {:ok, response} ->
        case response.status do
          404 ->
            Logger.info("User not in MailBluster.")
            add_user(user)

          200 ->
            Logger.info("User found in MailBluster.")
            update_user(user, current_mail_bluster_email)

          _something_else ->
            Logger.info("mailbluster_api_error")
            Logger.info(response)
        end

      {:error, error} ->
        Logger.info("mailbluster_api_error")
        Logger.error(error)
    end
  end

  def add_user(%{is_deleted: true} = user) do
    Logger.info(
      "Not adding user id #{user.id} #{user.email} to MailBluster because they are deleted"
    )
  end

  def add_user(%{is_deleted: false} = user) do
    Logger.info("Adding user id #{user.id} #{user.email} to MailBluster")

    case post("/leads", convert_user(user)) do
      {:ok, response} ->
        case response.status do
          422 ->
            Logger.error("Add user failed")
            Logger.debug(inspect(convert_user(user)))
            Logger.error(response.body)

          201 ->
            Logger.info("User added")
            Logger.debug(inspect(convert_user(user)))

          _something_else ->
            Logger.error("mailbluster_api_error")
            Logger.debug(inspect(convert_user(user)))
            Logger.info(response)
        end

      {:error, error} ->
        Logger.info("mailbluster_api_error")
        Logger.debug(inspect(convert_user(user)))
        Logger.error(error)
    end
  end

  def get_user(user, current_mail_bluster_email \\ nil) do
    hashed_email = hash_email(current_mail_bluster_email || user.email)
    get("/leads/#{hashed_email}")
  end

  def update_user(user, current_mail_bluster_email \\ nil)

  def update_user(%{is_deleted: true, email: email}, _current_mail_bluster_email) do
    delete_by_email(email)
  end

  def update_user(%{is_deleted: false} = user, current_mail_bluster_email) do
    Logger.info("Updating user id #{user.id} #{user.email} in MailBluster")
    hashed_email = hash_email(current_mail_bluster_email || user.email)

    case put("/leads/#{hashed_email}", convert_user(user)) do
      {:ok, response} ->
        case response.status do
          200 ->
            Logger.info("Updated successfully")

          _something_else ->
            Logger.error("mailbluster_api_error")
            Logger.info(response)
        end

      {:error, error} ->
        Logger.info("mailbluster_api_error")
        Logger.error(error)
    end
  end

  def delete_by_email(email) do
    Logger.info("Deleting lead #{email} from MailBluster...")

    case delete("/leads/#{hash_email(email)}") do
      {:ok, response} ->
        case response.status do
          200 ->
            Logger.info("Deleted user from MailBluster")

          404 ->
            Logger.info("User wasn't in MailBluster")

          _something_else ->
            Logger.error("mailbluster_api_error")
            Logger.error(response)
        end

      {:error, error} ->
        Logger.error("mailbluster_api_error")
        Logger.error(error)
    end
  end

  defp hash_email(email), do: :md5 |> :crypto.hash(email) |> Base.encode16()

  # https://app.mailbluster.com/api-doc/leads
  def convert_user(user),
    do: %{
      firstName: user.name,
      lastName: nil,
      email: user.email,
      timezone: nil,
      ipAddress: anonymise_ip(user.last_signed_in_ip),
      subscribed: user.is_subscribed_to_marketing_notifications,
      meta: %{id: user.id},
      userTags: add_user_tags(user),
      addTags: add_user_tags(user),
      removeTags: remove_user_tags(user)
    }

  defp add_user_tags(user) do
    user_tags(user)
  end

  defp remove_user_tags(user) do
    all_potential_user_tags() -- user_tags(user)
  end

  # A list of tags for each user. This allows you to segment your emails.
  # eg. you might want to send to all users who have confirmed their email.
  defp user_tags(user) do
    all_potential_user_tags()
    |> Enum.map(&if apply_tag?(&1, user), do: &1)
    |> Enum.filter(& &1)
  end

  defp all_potential_user_tags, do: ["is_confirmed", "is_suspended"]

  defp apply_tag?("is_confirmed", user), do: !!user.confirmed_at
  defp apply_tag?("is_suspended", user), do: !!user.is_suspended?

  # This will change the IP to still give a general location but not too specific
  defp anonymise_ip(ip) when is_binary(ip) do
    ip_as_array = String.split(ip, ".")

    if length(ip_as_array) == 4 do
      ip_as_array
      |> List.replace_at(-1, 0)
      |> Enum.join(".")

      # probably ipv6
    end
  end

  defp anonymise_ip(_rest), do: nil
end

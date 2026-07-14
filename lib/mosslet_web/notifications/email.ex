defmodule Mosslet.Notifications.Email do
  @moduledoc """
  Houses functions that generate Swoosh email structs.
  An Swoosh email struct can be delivered by a Swoosh mailer (see mailer.ex & user_notifier.ex). Eg:

      Mosslet.Notifications.Email.confirm_register_email(user.email, url)
      |> Mosslet.Mailer.deliver()
  """

  use Phoenix.Swoosh,
    view: MossletWeb.EmailView,
    layout: {MossletWeb.EmailView, :email_layout}

  use Gettext, backend: MossletWeb.Gettext

  def template(email) do
    base_email()
    |> to(email)
    |> subject(gettext("Template for showing how to do headings, buttons etc in emails"))
    |> render_body("template.html")
    |> premail()
  end

  def confirm_register_email(email, url) do
    base_email()
    |> to(email)
    |> subject(gettext("Confirm instructions"))
    |> render_body("confirm_register_email.html", %{url: url})
    |> premail()
  end

  def reset_password(email, url) do
    base_email()
    |> to(email)
    |> subject(gettext("Reset password"))
    |> render_body("reset_password.html", %{url: url})
    |> premail()
  end

  def change_email(email, url, new_email) do
    base_email()
    |> to(new_email)
    |> subject(gettext("Change email"))
    |> render_body("change_email.html", %{url: url, current_email: email, new_email: new_email})
    |> premail()
  end

  def notify_change_email(email, url, new_email) do
    base_email()
    |> to(email)
    |> subject(gettext("Change email notification"))
    |> render_body("change_email_notification.html", %{
      url: url,
      current_email: email,
      new_email: new_email
    })
    |> premail()
  end

  def org_invitation(to_email, org, invitation, url) do
    base_email()
    |> to(to_email)
    |> subject(org_invitation_subject(org))
    |> render_body("org_invitation.html", %{org: org, invitation: invitation, url: url})
    |> premail()
  end

  defp org_invitation_subject(%{type: :family} = org) do
    gettext("You're invited to join the %{org_name} family on MOSSLET", org_name: org.name)
  end

  defp org_invitation_subject(org) do
    gettext("You're invited to join %{org_name} on MOSSLET", org_name: org.name)
  end

  def unread_posts_notification_with_email(email, unread_count, timeline_url) do
    new()
    |> to(email)
    |> from({"Notifications @ MOSSLET", "notifications@mosslet.com"})
    |> subject(gettext("You have %{count} unread posts on MOSSLET", count: unread_count))
    |> render_body("unread_posts_notification.html", %{
      unread_count: unread_count,
      timeline_url: timeline_url
    })
    |> premail()
  end

  def unread_posts_notification(user, unread_count, timeline_url) do
    base_email()
    |> to(user.email)
    |> subject(gettext("You have %{count} unread posts on MOSSLET", count: unread_count))
    |> render_body("unread_posts_notification.html", %{
      unread_count: unread_count,
      timeline_url: timeline_url
    })
    |> premail()
  end

  def new_replies_notification_with_email(email, reply_count, timeline_url) do
    new()
    |> to(email)
    |> from({"Notifications @ MOSSLET", "notifications@mosslet.com"})
    |> subject(gettext("You have %{count} new replies on MOSSLET", count: reply_count))
    |> render_body("new_replies_notification.html", %{
      reply_count: reply_count,
      timeline_url: timeline_url
    })
    |> premail()
  end

  def circle_activity_notification_with_email(email, circles_url) do
    new()
    |> to(email)
    |> from({"Notifications @ MOSSLET", "notifications@mosslet.com"})
    |> subject(gettext("Activity in your circles 🌿"))
    |> render_body("circle_activity_notification.html", %{
      circles_url: circles_url
    })
    |> premail()
  end

  def passwordless_pin(email, pin) do
    base_email()
    |> to(email)
    |> subject(gettext("%{pin} is your pin code", pin: pin))
    |> render_body("passwordless_pin.html", %{pin: pin})
    |> premail()
  end

  @doc """
  A calm, content-free "a connection was thinking of you" note (EPIC #377,
  task #399).

  Deliberately GENERIC and metadata-only: it never names the sender (that would
  break zero-knowledge — the sender's name is only ever decrypted client-side on
  the dashboard, and an email can't run the browser hook) and never carries any
  content, because a nudge has none. Just a warm invitation to come say hello.
  """
  def nudge_notification(email, dashboard_url) do
    new()
    |> to(email)
    |> from({"MOSSLET", "notifications@mosslet.com"})
    |> subject(gettext("A connection was thinking of you 💜"))
    |> text_body(
      gettext(
        "Someone you're connected with was thinking of you on MOSSLET.\n\nNo message, no pressure — just a small hello. Drop by whenever you're ready:\n%{url}\n\n— MOSSLET",
        url: dashboard_url
      )
    )
  end

  @doc """
  A calm, content-free "a letter is waiting" note for time-capsule delivery.

  Carries only the mailbox URL and a coarse count — never a title, never a
  word of the letter. Deliberately quiet: no urgency, no dopamine.
  """
  def capsule_ready_notification(email, count, capsules_url) do
    new()
    |> to(email)
    |> from({"MOSSLET", "notifications@mosslet.com"})
    |> subject(gettext("A letter to your future self has arrived 💌"))
    |> text_body(
      gettext(
        "A letter you sealed to your future self is ready to open.\n\nYou have %{count} waiting in your time capsule. Whenever you're ready:\n%{url}\n\nWe only ever saw the date you chose — never a word you wrote.\n\n— MOSSLET",
        count: count,
        url: capsules_url
      )
    )
  end

  # For when you don't need any HTML and just want to send text
  def text_only_email(to_email, subject, body, cc \\ []) do
    new()
    |> to(to_email)
    |> from({from_name(), from_email()})
    |> subject(subject)
    |> text_body(body)
    |> cc(cc)
  end

  defp base_email(_opts \\ []) do
    new()
    |> from({from_name(), from_email()})
  end

  # Inlines your CSS and adds a text option (email clients prefer this)
  def referral_account_deletion(email, assigns) do
    base_email()
    |> to(email)
    |> subject(gettext("Your MOSSLET Referral Payout Account"))
    |> render_body("referral_account_deletion.html", assigns)
    |> premail()
  end

  defp premail(email) do
    html = Premailex.to_inline_css(email.html_body)
    text = Premailex.to_text(email.html_body)

    email
    |> html_body(html)
    |> text_body(text)
  end

  defp from_name do
    Mosslet.config(:mailer_default_from_name)
  end

  defp from_email do
    Mosslet.config(:mailer_default_from_email)
  end
end

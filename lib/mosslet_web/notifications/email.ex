defmodule Mosslet.Email do
  @moduledoc """
  Houses functions that generate Swoosh email structs.
  An Swoosh email struct can be delivered by a Swoosh mailer (see mailer.ex & user_notifier.ex). Eg:

      Mosslet.Email.confirm_register_email(user.email, url)
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

  def org_invitation(org, invitation, url) do
    base_email()
    |> to(invitation.email)
    |> subject(gettext("Invitation to join %{org_name}", org_name: org.name))
    |> render_body("org_invitation.html", %{org: org, invitation: invitation, url: url})
    |> premail()
  end

  def new_user_invitation(user, invitation, url) do
    base_email()
    |> to(invitation.email)
    |> subject(gettext("Invitation to join %{name} on MOSSLET 🌿", name: user.name))
    |> render_body("new_user_invite.html", %{user: user, invitation: invitation, url: url})
    |> premail()
  end

  def passwordless_pin(email, pin) do
    base_email()
    |> to(email)
    |> subject(gettext("%{pin} is your pin code", pin: pin))
    |> render_body("passwordless_pin.html", %{pin: pin})
    |> premail()
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

  defp base_email(opts \\ []) do
    {unsubscribe_url, _opts} = Keyword.pop(opts, :unsubscribe_url)

    new()
    |> from({from_name(), from_email()})
    |> assign(:unsubscribe_url, unsubscribe_url)
  end

  # Inlines your CSS and adds a text option (email clients prefer this)
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

  # Use this when you want to have different types of emails a user can sub/unsub to.
  # User field must begin with "is_subscribed_to_"
  # Eg:  user.is_subscribed_to_comment_replies
  # base_email(unsubscribe_url: unsub_url(comment_owner, "comment_replies"))
  def get_unsubscribe_url(user, email_kind) do
    Mosslet.Accounts.NotificationSubscriptions.unsubscribe_url(user, email_kind)
  end
end

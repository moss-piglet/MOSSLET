defmodule MossletWeb.EmailTestingController do
  use MossletWeb, :controller

  alias Mosslet.Notifications.Email
  alias Mosslet.Mailer

  @default_template "template"

  # How to add a new email notification:
  # 1. create new function in UserNotifier
  # 2. in this file add to @email_templates
  # 3. in this file add a new generate_email function

  @email_templates [
    "template",
    "register_confirm_email",
    "reset_password",
    "change_email",
    "org_invitation",
    "passwordless_pin"
  ]

  # Keep this to copy elements from it into your emails
  defp generate_email("template", current_user) do
    Email.template(current_user.email)
  end

  defp generate_email("register_confirm_email", current_user) do
    Email.confirm_register_email(current_user.email, "#")
  end

  defp generate_email("reset_password", current_user) do
    Email.reset_password(current_user.email, "#")
  end

  defp generate_email("change_email", current_user) do
    Email.change_email(current_user.email, "#", "newemail@example.com")
  end

  defp generate_email("org_invitation", current_user) do
    org = %{name: "MOSSLET", slug: "org"}
    invitation = %{email: current_user.email, user_id: current_user.id}
    Email.org_invitation(org, invitation, "#")
  end

  defp generate_email("passwordless_pin", current_user) do
    Email.passwordless_pin(current_user.email, "1234")
  end

  def index(conn, _params) do
    redirect(conn, to: ~p"/dev/emails/preview/#{@default_template}")
  end

  def sent(conn, _params) do
    render(conn)
  end

  def preview(conn, %{"email_name" => email_name}) do
    conn
    |> put_root_layout(html: {MossletWeb.Layouts, :empty})
    |> render(
      "index.html",
      %{
        email: generate_email(email_name, conn.assigns.current_user),
        email_name: email_name,
        email_options: @email_templates,
        iframe_url: url(~p"/dev/emails/show/#{email_name}")
      }
    )
  end

  def send_test_email(conn, %{"email_name" => email_name}) do
    if Util.email_valid?(conn.assigns.current_user.email) do
      email_name
      |> generate_email(conn.assigns.current_user)
      |> Mailer.deliver()

      conn
      |> put_flash(:info, "Email sent")
      |> redirect(to: ~p"/dev/emails/preview/#{email_name}")
    else
      conn
      |> put_flash(:error, "Email invalid")
      |> redirect(to: ~p"/dev/emails/preview/#{email_name}")
    end
  end

  def show_html(conn, %{"email_name" => email_name}) do
    email = generate_email(email_name, conn.assigns.current_user)

    conn
    |> put_layout(false)
    |> html(email.html_body)
  end
end

defmodule Mosslet.Extensions.Ecto.ChangesetExt do
  @moduledoc """
  Some extra validations for you to use:

  trim(changeset, :field)
  trim(changeset, [:field1, :field2])
  validate_email(changeset, :field)
  validate_url(changeset, field)

  """
  import Ecto.Changeset

  @doc """
  Trims the whitespace off both ends of the string.
  "  John Doe " -> "John Doe"

  Examples:

      defp changeset(user) do
        user
        |> cast([:first_name, :last_name, :email])
        |> trim([:first_name, :last_name])
        |> trim(:email)
      end
  """
  def ensure_trimmed(changeset, field) when is_atom(field) do
    update_change(changeset, field, &trim/1)
  end

  def ensure_trimmed(changeset, fields) when is_list(fields) do
    Enum.reduce(fields, changeset, fn field, cs ->
      update_change(cs, field, &trim/1)
    end)
  end

  @doc """
  Validate emails. Will check mx records in production (see the email_checker library).

  Examples:

      defp changeset(user) do
        user
        |> cast([:email])
        |> validate_email(:email)
      end
  """
  def validate_email(changeset, field) do
    changeset
    |> ensure_trimmed(field)
    |> validate_change(field, fn ^field, email ->
      if email_valid?(email), do: [], else: [email: "is invalid"]
    end)
    |> validate_length(field, max: 160)
  end

  @doc """
  Validate URLs. Adds https if a scheme doesn't exist.
  eg. "google.com" -> "https://google.com"

  Examples:

      defp changeset(user) do
        user
        |> cast([:website])
        |> validate_and_fix_url(:website)
      end
  """
  def validate_url(changeset, field) do
    url_change = get_change(changeset, field)

    cond do
      is_nil(url_change) ->
        changeset

      valid_url?(url_change) ->
        validate_url_works(changeset, field)

      without_scheme?(url_change) && valid_url?("https://" <> url_change) ->
        changeset
        |> force_change(field, "https://" <> url_change)
        |> validate_url_works(field)

      true ->
        add_error(changeset, field, "should be a HTTP or HTTPS link")
    end
  end

  def validate_url_works(changeset, field) do
    url = get_change(changeset, field)
    uri = URI.parse(url)

    case :inet.gethostbyname(to_charlist(uri.host)) do
      {:error, :nxdomain} ->
        add_error(
          changeset,
          field,
          "The link to #{uri.host} doesn't work. Did you spell it right?"
        )

      _ ->
        changeset
    end
  end

  def validate_website_link(changeset) do
    link_website = get_field(changeset, :link_website, "") || ""

    if link_website != "" do
      # parse website and look up the hostname
      link_website_parse = URI.parse("https://" <> link_website)

      if link_website_parse.host != nil do
      else
        changeset
      end
    else
      changeset
    end
  end

  defp valid_url?(url) when is_binary(url) do
    uri = URI.parse(url)
    uri.scheme in ~w(http https) && uri.host
  end

  defp without_scheme?(url) when is_binary(url) do
    is_nil(URI.parse(url).scheme)
  end

  def email_valid?(email) do
    EmailChecker.valid?(email)
  end

  @doc "Trim whitespace on either end of a string. Account for nil"
  def trim(str) when is_nil(str), do: str
  def trim(str) when is_binary(str), do: String.trim(str)
end

defmodule Mosslet.Security.EmailBlocklist do
  @moduledoc """
  Maintains a blocklist of email domains known to be associated with abuse.

  These domains are blocked from registration. The list is checked during
  email validation in changesets, before the more expensive MX record lookup.
  """

  # cock.li and all of its alias domains
  @blocked_domains [
    "cock.li",
    "cock.email",
    "airmail.cc",
    "420blaze.it",
    "tfwno.gf",
    "firemail.cc",
    "8chan.co",
    "memeware.net",
    "national.shitposting.agency",
    "horsefucker.org",
    "waifu.club",
    "cocaine.ninja",
    "cumallover.me",
    "goat.si",
    "loves.dicksinhisan.us",
    "wants.dicksinhisan.us",
    "dicksinhisan.us"
  ]

  @doc """
  Returns true if the given email domain is blocked.
  """
  @spec blocked?(String.t()) :: boolean()
  def blocked?(email) when is_binary(email) do
    case extract_domain(email) do
      nil -> false
      domain -> domain in @blocked_domains
    end
  end

  def blocked?(_), do: false

  @doc """
  Returns the list of blocked domains.
  """
  @spec blocked_domains() :: [String.t()]
  def blocked_domains, do: @blocked_domains

  defp extract_domain(email) do
    case String.split(email, "@") do
      [_, domain] -> String.downcase(domain)
      _ -> nil
    end
  end
end

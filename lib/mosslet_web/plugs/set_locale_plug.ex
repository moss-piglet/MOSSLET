defmodule Mosslet.SetLocalePlug do
  @moduledoc """
  A plug designed to set the locale based on the users preferences.

  Order of preference:
  1. is there a param? (/some-route?locale=fr)
  2. is there a cookie?
  3. is it in the HTTP header "referer"?
  4. is it in the HTTP header "accept-language"?
  """
  import Plug.Conn

  defmodule Config do
    @moduledoc false
    @enforce_keys [:gettext]
    defstruct [:gettext, extra_allowed_locales: []]
  end

  def init(opts) when is_tuple(hd(opts)), do: struct!(Config, opts)

  def call(conn, config) do
    locale =
      get_locale_from_params(conn, config) ||
        get_locale_from_cookie(conn, config) ||
        get_locale_from_http_referrer(conn, config) ||
        get_locale_from_header(conn, config)

    set_locale(conn, locale, config)
  end

  defp set_locale(conn, nil, _config), do: conn

  defp set_locale(conn, locale, config) do
    Gettext.put_locale(config.gettext, locale)

    conn
    |> put_resp_cookie("locale", locale, max_age: 365 * 24 * 60 * 60)
    |> persist_locale(locale)
  end

  # Attempt to extract a locale from the HTTP "referer" header.
  # If that url exists and had a language prefix, it's a good indication of what locale the user prefers.
  defp get_locale_from_http_referrer(conn, config) do
    conn
    |> get_req_header("referer")
    |> case do
      [referrer] when is_binary(referrer) ->
        uri = URI.parse(referrer)

        uri.path
        |> maybe_extract_locale()
        |> validate_locale(config)

      _ ->
        nil
    end
  end

  defp get_locale_from_params(conn, config) do
    validate_locale(conn.params["locale"], config)
  end

  defp get_locale_from_cookie(conn, config) do
    validate_locale(conn.cookies["locale"], config)
  end

  defp get_locale_from_header(conn, config) do
    conn
    |> extract_accept_language()
    |> Enum.find(nil, fn accepted_locale -> validate_locale(accepted_locale, config) end)
  end

  # If you want to set it on the user you can uncomment this
  # def get_locale_from_user(conn, config) do
  #   if conn.assigns.current_user do
  #     validate_locale(conn.assigns.current_user.locale, config)
  #   end
  # end

  defp validate_locale(locale, config) do
    if locale in available_locales(config) do
      locale
    end
  end

  defp persist_locale(conn, new_locale) do
    if conn.private.plug_session["locale"] != new_locale do
      put_session(conn, :locale, new_locale)
    else
      conn
    end
  end

  defp maybe_extract_locale(request_path) when is_binary(request_path) do
    case String.split(request_path, "/") do
      [_, maybe_locale | _] ->
        if locale?(maybe_locale), do: maybe_locale

      _ ->
        nil
    end
  end

  defp maybe_extract_locale(_), do: nil

  defp locale?(maybe_locale), do: Regex.match?(~r/^[a-z]{2}(-[a-z]{2})?$/, maybe_locale)

  defp extract_accept_language(conn) do
    case Plug.Conn.get_req_header(conn, "accept-language") do
      [value | _] ->
        value
        |> String.split(",")
        |> Enum.map(&parse_language_option/1)
        |> Enum.sort(&(&1.quality > &2.quality))
        |> Enum.map(& &1.tag)
        |> Enum.reject(&is_nil/1)
        |> ensure_language_fallbacks()

      _ ->
        []
    end
  end

  defp parse_language_option(string) do
    captures = Regex.named_captures(~r/^\s?(?<tag>[\w\-]+)(?:;q=(?<quality>[\d\.]+))?$/i, string)

    quality =
      case Float.parse(captures["quality"] || "1.0") do
        {val, _} -> val
        _ -> 1.0
      end

    %{tag: captures["tag"], quality: quality}
  end

  defp ensure_language_fallbacks(tags) do
    Enum.flat_map(tags, fn tag ->
      [language | _] = String.split(tag, "-")
      if Enum.member?(tags, language), do: [tag], else: [tag, language]
    end)
  end

  defp available_locales(%{gettext: gettext} = config) do
    Gettext.known_locales(gettext) ++ config.extra_allowed_locales
  end
end

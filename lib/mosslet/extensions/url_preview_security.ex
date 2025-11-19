defmodule Mosslet.Extensions.URLPreviewSecurity do
  @moduledoc """
  Security utilities for URL preview system.
  Provides SSRF protection, URL validation, and content sanitization.
  """

  @max_metadata_length 1000
  @allowed_schemes ["http", "https"]
  @allowed_ports [80, 443, 8080, 8443]

  @doc """
  Validates and normalizes a URL for preview fetching.
  Protects against SSRF attacks by:
  - Rejecting private IP ranges
  - Rejecting localhost
  - Rejecting link-local addresses
  - Enforcing HTTPS
  - Validating URL schemes
  """
  def validate_and_normalize_url(url) do
    url = String.trim(url)

    with {:ok, normalized_url} <- normalize_scheme(url),
         {:ok, uri} <- parse_uri(normalized_url),
         :ok <- validate_scheme(uri.scheme),
         :ok <- validate_host(uri.host),
         :ok <- validate_port(uri.port),
         :ok <- check_not_private_ip(uri.host) do
      {:ok, normalized_url}
    end
  end

  @doc """
  Sanitizes metadata by truncating overly long strings.
  """
  def sanitize_metadata(metadata) when is_map(metadata) do
    metadata
    |> Enum.map(fn {key, value} ->
      {key, truncate_string(value)}
    end)
    |> Enum.into(%{})
  end

  defp normalize_scheme(url) do
    cond do
      String.starts_with?(url, "http://") ->
        {:ok, String.replace_prefix(url, "http://", "https://")}

      String.starts_with?(url, "https://") ->
        {:ok, url}

      String.match?(url, ~r/^[a-zA-Z0-9]/) ->
        {:ok, "https://" <> url}

      true ->
        {:error, :invalid_url}
    end
  end

  defp parse_uri(url) do
    case URI.parse(url) do
      %URI{host: host} = uri when is_binary(host) ->
        {:ok, uri}

      _ ->
        {:error, :invalid_url}
    end
  end

  defp validate_scheme(scheme) when scheme in @allowed_schemes, do: :ok
  defp validate_scheme(_), do: {:error, :invalid_scheme}

  defp validate_host(nil), do: {:error, :missing_host}
  defp validate_host(""), do: {:error, :missing_host}
  defp validate_host(_host), do: :ok

  defp validate_port(nil), do: :ok
  defp validate_port(port) when port in @allowed_ports, do: :ok
  defp validate_port(_), do: {:error, :invalid_port}

  defp check_not_private_ip(host) do
    case resolve_host(host) do
      {:ok, ip_tuple} ->
        if private_ip?(ip_tuple) do
          {:error, :private_ip}
        else
          :ok
        end

      {:error, _reason} ->
        {:error, :invalid_host}
    end
  end

  defp resolve_host(host) do
    charlist_host = String.to_charlist(host)

    case :inet.getaddr(charlist_host, :inet) do
      {:ok, ip_tuple} ->
        {:ok, ip_tuple}

      {:error, :nxdomain} ->
        {:error, :dns_resolution_failed}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp private_ip?({a, b, c, d})
       when is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d) do
    cond do
      a == 10 -> true
      a == 127 -> true
      a == 172 and b >= 16 and b <= 31 -> true
      a == 192 and b == 168 -> true
      a == 169 and b == 254 -> true
      a == 0 -> true
      a == 255 -> true
      true -> false
    end
  end

  defp private_ip?(_), do: false

  defp truncate_string(value) when is_binary(value) do
    if String.length(value) > @max_metadata_length do
      String.slice(value, 0, @max_metadata_length)
    else
      value
    end
  end

  defp truncate_string(value), do: value
end

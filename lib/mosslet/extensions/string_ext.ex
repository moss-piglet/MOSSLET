defmodule Mosslet.Extensions.StringExt do
  # Copied from https://github.com/ikeikeikeike/phoenix_html_simplified_helpers/blob/master/lib/phoenix_html_simplified_helpers/truncate.ex
  @moduledoc false
  def truncate(text, options \\ []) do
    len = options[:length] || 30
    omi = options[:omission] || "..."

    cond do
      !String.valid?(text) ->
        text

      String.length(text) < len ->
        text

      true ->
        len_with_omi = len - String.length(omi)

        stop =
          if options[:separator] do
            rindex(text, options[:separator], len_with_omi) || len_with_omi
          else
            len_with_omi
          end

        "#{String.slice(text, 0, stop)}#{omi}"
    end
  end

  defp rindex(text, str, offset) do
    text = String.slice(text, 0, offset)
    reversed = String.reverse(text)
    matchword = String.reverse(str)

    case :binary.match(reversed, matchword) do
      {at, strlen} ->
        String.length(text) - at - strlen

      :nomatch ->
        nil
    end
  end
end

defmodule MossletWeb.HelpersLinkifyTest do
  use ExUnit.Case, async: true

  alias MossletWeb.Helpers

  describe "format_decrypted_content/1 linkification with punctuation" do
    test "preserves punctuation after URL in parentheses" do
      content = "Try Elixir (https://elixir-lang.org/)!"
      result = Helpers.format_decrypted_content(content)

      {:safe, html} = result
      assert html =~ "href=\"https://elixir-lang.org/\""
      assert html =~ "</a>)!"
      assert html =~ "Try Elixir ("
    end

    test "preserves period after URL" do
      content = "Visit https://example.com."
      result = Helpers.format_decrypted_content(content)

      {:safe, html} = result
      assert html =~ "href=\"https://example.com\""
      assert html =~ "</a>."
    end

    test "preserves exclamation after URL" do
      content = "Check this out: https://example.com/page!"
      result = Helpers.format_decrypted_content(content)

      {:safe, html} = result
      assert html =~ "href=\"https://example.com/page\""
      assert html =~ "</a>!"
    end

    test "handles URL with parentheses in path correctly" do
      content = "https://en.wikipedia.org/wiki/Phoenix_(web_framework)"
      result = Helpers.format_decrypted_content(content)

      {:safe, html} = result
      assert html =~ "href=\"https://en.wikipedia.org/wiki/Phoenix_(web_framework)\""
      refute html =~ "</a>)"
    end

    test "handles URL followed by closing parenthesis and exclamation" do
      content = "See this (https://example.com)!"
      result = Helpers.format_decrypted_content(content)

      {:safe, html} = result
      assert html =~ "href=\"https://example.com\""
      assert html =~ "</a>)!"
    end
  end
end

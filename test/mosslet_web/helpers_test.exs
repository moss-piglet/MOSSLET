defmodule MossletWeb.HelpersTest do
  use ExUnit.Case, async: true

  alias MossletWeb.Helpers

  describe "format_decrypted_content/1 with URLs" do
    test "handles URL in parentheses with trailing punctuation" do
      content = "Try Elixir (https://elixir-lang.org/)!"
      result = Helpers.format_decrypted_content(content)

      {:safe, html} = result
      assert html =~ "href=\"https://elixir-lang.org/\""
      refute html =~ "href=\"https://elixir-lang.org/)!\""
    end

    test "handles URL with parentheses in the path" do
      content = "https://en.wikipedia.org/wiki/Phoenix_(web_framework)"
      result = Helpers.format_decrypted_content(content)

      {:safe, html} = result
      assert html =~ "href=\"https://en.wikipedia.org/wiki/Phoenix_(web_framework)\""
    end

    test "handles URL with trailing punctuation" do
      content = "Check this out: https://example.com/page!"
      result = Helpers.format_decrypted_content(content)

      {:safe, html} = result
      assert html =~ "href=\"https://example.com/page\""
      refute html =~ "href=\"https://example.com/page!\""
    end

    test "handles URL with trailing period" do
      content = "Visit https://example.com."
      result = Helpers.format_decrypted_content(content)

      {:safe, html} = result
      assert html =~ "href=\"https://example.com\""
      refute html =~ "href=\"https://example.com.\""
    end

    test "handles URL with query parameters and trailing period" do
      content = "Go to https://example.com/path?query=value&other=123."
      result = Helpers.format_decrypted_content(content)

      {:safe, html} = result
      assert html =~ "href=\"https://example.com/path?query=value&amp;other=123\""
      refute html =~ "href=\"https://example.com/path?query=value&amp;other=123.\""
    end

    test "handles URL with unbalanced closing parenthesis" do
      content = "See (https://example.com/page)"
      result = Helpers.format_decrypted_content(content)

      {:safe, html} = result
      assert html =~ "href=\"https://example.com/page\""
      refute html =~ "href=\"https://example.com/page)\""
    end

    test "handles http URLs" do
      content = "Visit http://example.com"
      result = Helpers.format_decrypted_content(content)

      {:safe, html} = result
      assert html =~ "href=\"http://example.com\""
    end
  end
end

defmodule MossletWeb.ErrorHTMLTest do
  use MossletWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template

  test "renders 404.html" do
    assert String.contains?(
             render_to_string(MossletWeb.ErrorHTML, "404", "html", []),
             "Sorry, we couldn’t find the page you’re looking for."
           )
  end

  test "renders 500.html" do
    assert String.contains?(
             render_to_string(MossletWeb.ErrorHTML, "500", "html", []),
             "Sorry, something went wrong."
           )
  end
end

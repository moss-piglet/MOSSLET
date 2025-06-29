defmodule MossletComponents do
  @moduledoc false
  defmacro __using__(_) do
    quote do
      import MossletWeb.AuthLayout
      import MossletWeb.ColorSchemeSwitch
      import MossletWeb.ComboBox
      import MossletWeb.ContentEditor
      import MossletWeb.DataTable
      import MossletWeb.Flash
      import MossletWeb.FloatingDiv
      import MossletWeb.LocalTime
      import MossletWeb.Markdown
      import MossletWeb.Navbar
      import MossletWeb.PageComponents
      import MossletWeb.PublicLayout
      import MossletWeb.RouteTree
      import MossletWeb.SidebarLayout
      import MossletWeb.StackedLayout
    end
  end
end

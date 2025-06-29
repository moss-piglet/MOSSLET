defmodule Mosslet.ZXCVBNMessageFormatter do
  @moduledoc false
  def format(str) do
    Gettext.dgettext(MossletWeb.Gettext, "zxcvbn", str)
  end
end

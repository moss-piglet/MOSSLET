defmodule Mosslet.Cldr do
  @moduledoc false
  use Cldr,
    gettext: MossletWeb.Gettext,
    locales: ["en"],
    providers: [Cldr.Number, Cldr.Calendar, Cldr.DateTime]
end

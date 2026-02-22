import Config

import_config "dev.exs"
import_config "desktop.exs"

config :phoenix_live_view,
  debug_heex_annotations: false,
  debug_tags_location: false,
  debug_attributes: false

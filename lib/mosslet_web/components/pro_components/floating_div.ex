defmodule MossletWeb.FloatingDiv do
  @moduledoc false
  use Phoenix.Component

  @doc """
  A Floating UI positioned div, attached to an element of your choosing on mount.
  Renders as hidden before mounting to prevent flash of unstyled content issues.
  """

  attr :id, :string, required: true, doc: "The ID of the floating div container."

  attr :attach_to_id, :string,
    required: true,
    doc: "The ID of the element to attach to on mount with Floating UI."

  attr :class, :string,
    default: "",
    doc:
      "Classes to apply to the floating div, in addition to Floating UI required defaults (`hidden absolute w-max top-0 left-0`)"

  attr :placement, :string,
    default: "right-start",
    doc:
      "The position of the flyout relative to the element it's attached to. Defaults to `right-start`, see [Floating UI docs](https://floating-ui.com/docs/tutorial#placements) for available values."

  attr :show_on_mount, :boolean,
    default: false,
    doc:
      "Whether to show the floating div on mount. Defaults to false so it's hidden until triggered otherwise."

  attr :float_offset, :map,
    default: nil,
    doc:
      "A map of options to pass to Floating UI offset middleware client-side. For example: `%{\"mainAxis\" => 32}`. Defaults to `nil`. See [Floating UI Docs](https://floating-ui.com/docs/offset#options)."

  attr :rest, :global, doc: "Any additional HTML attributes to add to the floating container."

  slot :inner_block, required: true

  def floating_div(assigns) do
    ~H"""
    <div
      id={@id}
      class={"hidden absolute w-max top-0 left-0 #{@class}"}
      phx-hook="FloatingHook"
      data-attach-to-id={@attach_to_id}
      data-placement={@placement}
      data-show-on-mount={"#{@show_on_mount}"}
      data-float-offset={maybe_encode_opts(@float_offset)}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp maybe_encode_opts(nil), do: nil
  defp maybe_encode_opts(opts), do: Jason.encode!(opts)
end

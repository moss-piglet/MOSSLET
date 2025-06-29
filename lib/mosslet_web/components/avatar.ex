defmodule MossletWeb.Components.Avatar do
  @moduledoc false
  use Phoenix.Component
  import PetalComponents.{Icon, Loading}
  import MossletWeb.CoreComponents, only: [phx_avatar: 1]

  attr(:src, :string, default: nil, doc: "hosted avatar URL")
  attr(:size, :string, default: "md", values: ["xs", "sm", "md", "lg", "xl"])
  attr(:class, :string, default: "", doc: "CSS class")
  attr(:name, :string, default: nil, doc: "name for placeholder initials")

  attr(:random_color, :boolean,
    default: false,
    doc: "generates a random color for placeholder initials avatar"
  )

  attr(:rest, :global)
  attr :key, :string, default: nil, doc: "user session key for decrypting the avatar"

  def avatar(assigns) do
    ~H"""
    <%= if src_nil?(@src) && !@name do %>
      <div
        {@rest}
        class={[
          "pc-avatar--with-placeholder-icon",
          "pc-avatar--#{@size}",
          @class
        ]}
      >
        <.icon name="hero-user" solid class="pc-avatar__placeholder-icon" />
      </div>
    <% else %>
      <%= if src_nil?(@src) && @name do %>
        <div
          {@rest}
          style={maybe_generate_random_color(@random_color, @name)}
          class={[
            "pc-avatar--with-placeholder-initials",
            "pc-avatar--#{@size}",
            @class
          ]}
        >
          {generate_initials(@name)}
        </div>
      <% else %>
        <%= if @src == "" && @name do %>
          <div
            {@rest}
            class={[
              "pc-avatar--with-placeholder-initials",
              "pc-avatar--#{@size}",
              @class
            ]}
          >
            <.spinner size={@size} class="text-primary-500" />
          </div>
        <% else %>
          <img
            {@rest}
            src={@src}
            class={[
              "pc-avatar--with-image",
              "pc-avatar--#{@size}",
              @class
            ]}
          />
        <% end %>
      <% end %>
    <% end %>
    """
  end

  attr(:size, :string, default: "md", values: ["xs", "sm", "md", "lg", "xl"])
  attr(:class, :string, default: "", doc: "CSS class")
  attr(:avatars, :list, default: [], doc: "list of your hosted avatar URLs")
  attr(:rest, :global)

  def avatar_group(assigns) do
    ~H"""
    <div {@rest} class={["pc-avatar-group--#{@size}", @class]}>
      <%= for src <- @avatars do %>
        <.phx_avatar src={src} size={@size} class="pc-avatar-group" />
      <% end %>
    </div>
    """
  end

  defp src_nil?(src), do: !src

  defp maybe_generate_random_color(false, _), do: nil

  defp maybe_generate_random_color(true, name) do
    "background-color: #{generate_color_from_string(name)}; color: white;"
  end

  defp generate_color_from_string(string) do
    a_number =
      string
      |> String.to_charlist()
      |> Enum.reduce(0, fn x, acc -> x + acc end)

    "hsl(#{rem(a_number, 360)}, 100%, 35%)"
  end

  defp generate_initials(name) when is_binary(name) do
    word_array = String.split(name)

    if length(word_array) == 1 do
      List.first(word_array)
      |> String.slice(0..1)
      |> String.upcase()
    else
      initial1 = String.first(List.first(word_array))
      initial2 = String.first(List.last(word_array))
      String.upcase(initial1 <> initial2)
    end
  end

  defp generate_initials(_) do
    ""
  end
end

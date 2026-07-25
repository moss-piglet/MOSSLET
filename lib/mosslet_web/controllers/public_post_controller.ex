defmodule MossletWeb.PublicPostController do
  use MossletWeb, :controller

  alias Mosslet.Timeline

  @moduledoc """
  Web fallback for public post permalinks.

  RSS feed items link here, and the native apps claim `/post/*` via universal
  links. Public posts are read on the public timeline, so we redirect there;
  anything else 404s so we never leak that a non-public post exists.
  """

  def show(conn, %{"id" => id}) do
    with {:ok, post_id} <- Ecto.UUID.cast(id),
         %Timeline.Post{visibility: :public} <- Timeline.get_post_with_preloads(post_id) do
      redirect(conn, to: ~p"/discover")
    else
      _ -> send_resp(conn, 404, "Post not found")
    end
  end
end

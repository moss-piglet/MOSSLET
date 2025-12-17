defmodule MossletWeb.API.PostControllerTest do
  use MossletWeb.ConnCase

  import Mosslet.AccountsFixtures
  import Mosslet.TimelineFixtures, except: [unique_user_email: 0, unique_username: 0]

  alias Mosslet.API.Token
  alias Mosslet.Accounts.User

  @valid_password "hello world hello world!"

  setup %{conn: conn} do
    email = unique_user_email()
    user = user_fixture(%{email: email, password: @valid_password})
    {:ok, session_key} = User.valid_key_hash?(user, @valid_password)
    {:ok, token} = Token.generate(user, session_key)

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    {:ok, conn: conn, user: user, session_key: session_key}
  end

  describe "GET /api/posts" do
    test "returns empty list when no posts", %{conn: conn} do
      conn = get(conn, ~p"/api/posts")

      assert %{"posts" => [], "has_more" => false} = json_response(conn, 200)
    end

    test "returns user's posts", %{conn: conn, user: user, session_key: session_key} do
      _post =
        post_fixture(%{body: "Test post", visibility: "private"}, user: user, key: session_key)

      conn = get(conn, ~p"/api/posts")

      assert %{"posts" => [post_data], "has_more" => false} = json_response(conn, 200)
      assert post_data["body"] != nil
    end

    test "supports since parameter", %{conn: conn} do
      since = DateTime.utc_now() |> DateTime.to_iso8601()
      conn = get(conn, ~p"/api/posts?since=#{since}")

      assert %{"posts" => _, "has_more" => _} = json_response(conn, 200)
    end

    test "supports limit parameter", %{conn: conn} do
      conn = get(conn, ~p"/api/posts?limit=5")

      assert %{"posts" => _} = json_response(conn, 200)
    end
  end

  describe "GET /api/posts/:id" do
    test "returns a specific post", %{conn: conn, user: user, session_key: session_key} do
      post =
        post_fixture(%{body: "Specific post", visibility: "private"},
          user: user,
          key: session_key
        )

      conn = get(conn, ~p"/api/posts/#{post.id}")

      assert %{"post" => post_data} = json_response(conn, 200)
      assert post_data["id"] == post.id
    end

    test "returns 404 for non-existent post", %{conn: conn} do
      conn = get(conn, ~p"/api/posts/#{Ecto.UUID.generate()}")

      assert json_response(conn, 404)
    end

    test "returns 404 for other user's post", %{conn: conn} do
      other_user = user_fixture(%{email: unique_user_email(), password: @valid_password})
      {:ok, other_key} = User.valid_key_hash?(other_user, @valid_password)

      other_post =
        post_fixture(%{body: "Other user post", visibility: "private"},
          user: other_user,
          key: other_key
        )

      conn = get(conn, ~p"/api/posts/#{other_post.id}")

      assert json_response(conn, 404)
    end
  end

  describe "POST /api/posts" do
    test "creates a private post", %{conn: conn} do
      conn =
        post(conn, ~p"/api/posts", %{
          post: %{
            body: "New post body",
            visibility: "private"
          }
        })

      assert %{"post" => post_data} = json_response(conn, 201)
      assert post_data["id"] != nil
      assert post_data["visibility"] == "private"
    end

    test "returns validation error for connections visibility without connections", %{conn: conn} do
      conn =
        post(conn, ~p"/api/posts", %{
          post: %{
            body: "Post body",
            visibility: "connections"
          }
        })

      assert %{"error" => "validation_error", "errors" => errors} = json_response(conn, 422)
      assert errors["body"] != nil
    end

    test "returns validation error for invalid visibility", %{conn: conn} do
      conn =
        post(conn, ~p"/api/posts", %{
          post: %{
            body: nil,
            visibility: "invalid"
          }
        })

      assert json_response(conn, 422)
    end
  end

  describe "PUT /api/posts/:id" do
    test "updates own post", %{conn: conn, user: user, session_key: session_key} do
      post =
        post_fixture(%{body: "Original body", visibility: "private"},
          user: user,
          key: session_key
        )

      conn =
        put(conn, ~p"/api/posts/#{post.id}", %{
          post: %{body: "Updated body"}
        })

      assert %{"post" => post_data} = json_response(conn, 200)
      assert post_data["id"] == post.id
    end

    test "returns 404 for non-existent post", %{conn: conn} do
      conn =
        put(conn, ~p"/api/posts/#{Ecto.UUID.generate()}", %{
          post: %{body: "Updated body"}
        })

      assert json_response(conn, 404)
    end

    test "returns 403 for other user's post", %{conn: conn} do
      other_user = user_fixture(%{email: unique_user_email(), password: @valid_password})
      {:ok, other_key} = User.valid_key_hash?(other_user, @valid_password)

      other_post =
        post_fixture(%{body: "Other user post", visibility: "private"},
          user: other_user,
          key: other_key
        )

      conn =
        put(conn, ~p"/api/posts/#{other_post.id}", %{
          post: %{body: "Trying to update"}
        })

      assert json_response(conn, 403)
    end
  end

  describe "DELETE /api/posts/:id" do
    test "deletes own post", %{conn: conn, user: user, session_key: session_key} do
      post =
        post_fixture(%{body: "Post to delete", visibility: "private"},
          user: user,
          key: session_key
        )

      conn = delete(conn, ~p"/api/posts/#{post.id}")

      assert %{"message" => _} = json_response(conn, 200)

      assert get(conn, ~p"/api/posts/#{post.id}") |> json_response(404)
    end

    test "returns 404 for non-existent post", %{conn: conn} do
      conn = delete(conn, ~p"/api/posts/#{Ecto.UUID.generate()}")

      assert json_response(conn, 404)
    end

    test "returns 403 for other user's post", %{conn: conn} do
      other_user = user_fixture(%{email: unique_user_email(), password: @valid_password})
      {:ok, other_key} = User.valid_key_hash?(other_user, @valid_password)

      other_post =
        post_fixture(%{body: "Other user post", visibility: "private"},
          user: other_user,
          key: other_key
        )

      conn = delete(conn, ~p"/api/posts/#{other_post.id}")

      assert json_response(conn, 403)
    end
  end

  describe "unauthenticated access" do
    test "returns 401 for missing token" do
      conn = build_conn() |> put_req_header("content-type", "application/json")

      assert conn |> get(~p"/api/posts") |> json_response(401)
      assert conn |> post(~p"/api/posts", %{post: %{}}) |> json_response(401)
    end
  end
end

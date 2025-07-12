defmodule Mosslet.Timeline do
  @moduledoc """
  The Timeline context.
  """
  require Logger

  import Ecto.Query, warn: false

  alias Mosslet.Accounts
  alias Mosslet.Accounts.{Connection, User, UserConnection}
  alias Mosslet.Groups
  alias Mosslet.Repo
  alias Mosslet.Timeline.{Post, Reply, UserPost, UserPostReceipt}

  @doc """
  Counts all posts.
  """
  def count_all_posts() do
    query = from(p in Post)
    Repo.aggregate(query, :count)
  end

  @doc """
  Gets the total count of a user's Posts. An
  optional filter can be applied.
  """
  def post_count(user, options) do
    query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: up.user_id == ^user.id and p.visibility != :public
      )
      |> filter_by_user_id(options)

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Gets the total count of a user's Posts that have
  been shared with the current_user by another user.
  Does not include group Posts.
  """
  def shared_between_users_post_count(user_id, current_user_id) do
    query =
      Post
      |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
      |> join(:inner, [p, up], up2 in UserPost, on: up2.post_id == p.id)
      |> where([p, up, up2], up.user_id == ^user_id and up2.user_id == ^current_user_id)
      |> where([p, up, up2], p.visibility == :connections)
      |> where([p, up, up2], is_nil(p.group_id))

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Gets the total count of a current_user's posts
  on their timeline page.
  """
  def timeline_post_count(current_user, options) do
    query =
      Post
      |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
      |> where([p, up], up.user_id == ^current_user.id)
      |> with_any_visibility([:private, :connections])
      |> filter_by_user_id(options)
      |> preload([:user_posts])

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Gets the total count of a post's Replies. An
  optional filter can be applied.

  Subquery on the user_connection to ensure
  only connections are viewing their connections' replies.
  """
  def reply_count(post, options) do
    user_connection_query = user_connection_subquery(options.current_user_id)

    query =
      Reply
      |> join(:inner, [r], p in assoc(r, :post))
      |> where([r, p], r.post_id == ^post.id)
      |> filter_by_user_id(options)
      |> where(
        [r, p],
        r.user_id in subquery(user_connection_query) or r.user_id == ^options.current_user_id
      )

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Gets the total count of a public post's public Replies. An
  optional filter can be applied.

  This does not apply a current user check.
  """
  def public_reply_count(post, options) do
    query =
      Reply
      |> join(:inner, [r], p in assoc(r, :post))
      |> where([r, p], r.post_id == ^post.id)
      |> where([r, p], r.visibility == :public and p.visibility == :public)
      |> filter_by_user_id(options)

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  def preload_group(post) do
    post |> Repo.preload([:group])
  end

  # we use this subquery to fetch user connections
  # to check them against a main query
  defp user_connection_subquery(current_user_id) do
    UserConnection
    |> where([uc], uc.user_id == ^current_user_id)
    |> select([uc], uc.reverse_user_id)
  end

  @doc """
  Gets the total count of a group's Posts.
  """
  def group_post_count(group) do
    query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: p.group_id == ^group.id,
        where: p.visibility == :connections
      )

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Gets the total count of Public Posts. An
  optional filter can be applied.
  """
  def public_post_count(_user, options) do
    query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: p.visibility == :public
      )
      |> filter_by_user_id(options)

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Gets the total count of a profile_user's
  Public Posts.
  """
  def public_post_count(user) do
    query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: p.user_id == ^user.id and p.visibility == :public
      )

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Returns all post for a user. Used when
  deleting data in settings.
  """
  def get_all_posts(user) do
    from(p in Post,
      where: p.user_id == ^user.id
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of non-public posts for
  the user. This includes posts shared
  with user or the user's own uploaded posts.

  Example options:

  %{sort_by: :item, sort_order: :asc, page: 2, per_page: 5}

  ## Examples

      iex> list_posts(user, options)
      [%Post{}, ...]

  """
  def list_posts(user, options) do
    from(p in Post,
      inner_join: up in UserPost,
      on: up.post_id == p.id,
      where: up.user_id == ^user.id and p.visibility != :public,
      order_by: [desc: p.inserted_at],
      preload: [:user_posts, :group, :user_group, :replies]
    )
    |> filter_by_user_id(options)
    |> sort(options)
    |> paginate(options)
    |> Repo.all()
  end

  @doc """
  Returns the list of replies for a post.

  Checks the user_connection_query to return only relevantly
  connected replies.
  """
  def list_replies(post, options) do
    user_connection_query = user_connection_subquery(options.current_user_id)

    Reply
    |> join(:inner, [r], p in assoc(r, :post))
    |> where([r, p], r.post_id == ^post.id)
    |> where(
      [r, p],
      r.user_id in subquery(user_connection_query) or r.user_id == ^options.current_user_id
    )
    |> reply_sort(options)
    |> paginate(options)
    |> preload([:user, :post])
    |> Repo.all()
  end

  @doc """
  Returns the first (latest) reply for a post.
  """
  def first_reply(post, options) do
    user_connection_query = user_connection_subquery(options.current_user_id)

    Reply
    |> join(:inner, [r], p in Post, on: p.id == r.post_id)
    |> where([r, p], r.post_id == ^post.id)
    |> where(
      [r, p],
      r.user_id in subquery(user_connection_query) or r.user_id == ^options.current_user_id
    )
    |> sort(options)
    |> preload([:user, :post])
    |> Repo.first()
  end

  @doc """
  Returns the first (latest) public reply for a post.

  This does not apply a current_user check.
  """
  def first_public_reply(post, options) do
    Reply
    |> join(:inner, [r], p in Post, on: p.id == r.post_id)
    |> where([r, p], r.post_id == ^post.id)
    |> sort(options)
    |> preload([:user, :post])
    |> Repo.first()
  end

  @doc """
  Returns a list of posts shared between two users.
  """
  def list_shared_posts(user_id, current_user_id, options) do
    Post
    |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
    |> join(:inner, [p, up], up2 in UserPost, on: up2.post_id == p.id)
    |> where([p, up, up2], up.user_id == ^user_id and up2.user_id == ^current_user_id)
    |> where([p, up, up2], p.user_id == ^user_id or p.user_id == ^current_user_id)
    |> where([p, up, up2], p.visibility == :connections)
    |> sort(options)
    |> paginate(options)
    |> preload([:user_posts, :group, :user_group, :replies])
    |> Repo.all()
  end

  @doc """
  Returns a list of posts for the current_user's
  timeline. Non public posts.
  """
  def filter_timeline_posts(current_user, options) do
    Post
    |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
    |> where([p, up], up.user_id == ^current_user.id)
    |> join(:left, [p, up, upr], upr in UserPostReceipt, on: upr.user_post_id == up.id)
    |> with_any_visibility([:private, :connections])
    |> filter_by_user_id(options)
    |> preload([:user_posts, :user, :replies, :user_post_receipts])
    |> order_by([p, up, upr],
      # Unread posts first (fals comes before true)
      asc: upr.is_read?,
      # Most recent posts first within each group
      desc: p.inserted_at,
      # Secondary sort on read_at
      asc: upr.read_at
    )
    |> paginate(options)
    |> Repo.all()
  end

  @doc """
  Returns a list of posts for the current_user that
  have not been read yet.
  """
  def unread_posts(current_user) do
    Post
    |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
    |> where([p, up], p.user_id != ^current_user.id)
    |> join(:inner, [p, up, upr], upr in UserPostReceipt, on: upr.user_post_id == up.id)
    |> where([p, up, upr], upr.user_id == ^current_user.id)
    |> where([p, up, upr], not upr.is_read? and is_nil(upr.read_at))
    |> with_any_visibility([:private, :connections])
    # Unread posts first (false comes before true)
    |> order_by([p, up, upr],
      asc: upr.is_read?,
      # Most recent posts first within each group
      desc: p.inserted_at,
      # Secondary sort on read_at
      asc: upr.read_at
    )
    |> preload([:user_posts, :user, :replies])
    |> Repo.all()
  end

  defp with_any_visibility(query, visibility_list) do
    where(query, [p], p.visibility in ^visibility_list)
  end

  @doc """
  Returns the list of public posts.

  Example options:

  %{sort_by: :item, sort_order: :asc, page: 2, per_page: 5}

  ## Examples

      iex> list_public_posts(user, options)
      [%Post{}, ...]

  """
  def list_public_posts(options) do
    from(p in Post,
      inner_join: up in UserPost,
      on: up.post_id == p.id,
      where: p.visibility == :public,
      order_by: [desc: p.inserted_at],
      preload: [:user_posts, :replies]
    )
    |> filter_by_user_id(options)
    |> sort(options)
    |> paginate_public(options)
    |> Repo.all()
  end

  def list_public_replies(post, options) do
    from(r in Reply,
      inner_join: p in Post,
      on: p.id == r.post_id,
      where: r.post_id == ^post.id,
      where: r.visibility == :public,
      order_by: [desc: r.inserted_at],
      preload: [:user, :post]
    )
    |> filter_by_user_id(options)
    |> sort(options)
    |> paginate_public(options)
    |> Repo.all()
  end

  @doc """
  Returns the list of public posts for the
  user profile being viewed.

  Example options:

  %{sort_by: :item, sort_order: :asc, page: 2, per_page: 5}

  ## Examples

      iex> list_public_profile_posts(user, options)
      [%Post{}, ...]

  """
  def list_public_profile_posts(user, options) do
    from(p in Post,
      inner_join: up in UserPost,
      on: up.post_id == p.id,
      where: p.user_id == ^user.id and p.visibility == :public,
      order_by: [desc: p.inserted_at],
      preload: [:user_posts, :group, :user_group, :replies]
    )
    |> sort(options)
    |> paginate_public(options)
    |> Repo.all()
  end

  defp filter_by_user_id(query, %{filter: %{user_id: ""}}), do: query

  defp filter_by_user_id(query, %{filter: %{user_id: user_id}}) do
    query
    |> where([p, up, upr], p.user_id == ^user_id)
  end

  defp sort(query, %{sort_by: sort_by, sort_order: sort_order}) do
    order_by(query, {^sort_order, ^sort_by})
  end

  defp sort(query, %{post_sort_by: sort_by, post_sort_order: sort_order}) do
    order_by(query, {^sort_order, ^sort_by})
  end

  defp sort(query, _options), do: query

  defp reply_sort(query, %{sort_by: sort_by, sort_order: sort_order}) do
    order_by(query, {^sort_order, ^sort_by})
  end

  defp reply_sort(query, _options), do: query

  defp paginate(query, %{page: page, per_page: per_page}) do
    offset = max((page - 1) * per_page, 0)

    query
    |> limit(^per_page)
    |> offset(^offset)
  end

  defp paginate(query, %{post_page: page, post_per_page: per_page}) do
    offset = max((page - 1) * per_page, 0)

    query
    |> limit(^per_page)
    |> offset(^offset)
  end

  defp paginate(query, _options), do: query

  defp paginate_public(query, %{post_page: page, post_per_page: per_page}) do
    offset = max((page - 1) * per_page, 0)

    query
    |> limit(^per_page)
    |> offset(^offset)
  end

  defp paginate_public(query, _options), do: query

  @doc """
  Used only in group's show page.
  """
  def list_group_posts(group, options) do
    from(p in Post,
      join: up in UserPost,
      on: up.post_id == p.id,
      where: p.group_id == ^group.id,
      order_by: [desc: p.inserted_at],
      preload: [:user_posts, :group, :user_group, :replies]
    )
    |> filter_by_user_id(options)
    |> sort(options)
    |> paginate(options)
    |> Repo.all()
  end

  @doc """
  Lists all posts for a group and user.
  """
  def list_user_group_posts(group, user) do
    from(p in Post,
      join: up in UserPost,
      on: up.post_id == p.id,
      where: p.group_id == ^group.id,
      where: p.user_id == ^user.id,
      order_by: [desc: p.inserted_at],
      preload: [:user_posts, :group, :user_group, :replies]
    )
    |> Repo.all()
  end

  def list_own_connection_posts(user, opts) do
    limit = Keyword.fetch!(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)

    from(p in Post,
      join: up in UserPost,
      on: up.post_id == p.id,
      join: u in User,
      on: up.user_id == u.id,
      where: p.visibility == :connections and p.user_id == ^user.id,
      where: is_nil(p.group_id),
      offset: ^offset,
      limit: ^limit,
      order_by: [desc: p.inserted_at],
      preload: [:user_posts, :group, :user_group]
    )
    |> Repo.all()
  end

  def list_connection_posts(user, opts) do
    limit = Keyword.fetch!(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)

    from(p in Post,
      join: up in UserPost,
      on: up.post_id == p.id,
      join: u in User,
      on: up.user_id == u.id,
      join: c in Connection,
      on: c.user_id == u.id,
      join: uc in UserConnection,
      on: uc.connection_id == c.id,
      where: uc.user_id == ^user.id or uc.reverse_user_id == ^user.id,
      where: is_nil(p.group_id),
      where: not is_nil(uc.confirmed_at),
      where: p.visibility == :connections,
      offset: ^offset,
      limit: ^limit,
      order_by: [desc: p.inserted_at],
      preload: [:user_posts, :group, :user_group]
    )
    |> Repo.all()
    |> Enum.filter(fn post ->
      Enum.empty?(post.shared_users) ||
        Enum.any?(post.shared_users, fn x -> x.user_id == user.id end)
    end)
    |> Enum.sort_by(fn p -> p.inserted_at end, :desc)
  end

  def inc_favs(%Post{id: id}) do
    {:ok, {1, [post]}} =
      Repo.transaction_on_primary(fn ->
        from(p in Post, where: p.id == ^id, select: p)
        |> Repo.update_all(inc: [favs_count: 1])
      end)

    {:ok, post |> Repo.preload([:user_posts, :replies])}
  end

  def decr_favs(%Post{id: id}) do
    {:ok, {1, [post]}} =
      Repo.transaction_on_primary(fn ->
        from(p in Post, where: p.id == ^id, select: p)
        |> Repo.update_all(inc: [favs_count: -1])
      end)

    {:ok, post |> Repo.preload([:user_posts, :replies])}
  end

  def inc_reposts(%Post{id: id}) do
    {1, [post]} =
      from(p in Post, where: p.id == ^id, select: p)
      |> Repo.update_all(inc: [reposts_count: 1])

    {:ok, post |> Repo.preload([:user_posts, :replies])}
  end

  @doc """
  Gets a single post.

  Raises `Ecto.NoResultsError` if the Post does not exist.

  ## Examples

      iex> get_post!(123)
      %Post{}

      iex> get_post!(456)
      ** (Ecto.NoResultsError)

  """
  def get_post!(id),
    do:
      Repo.get!(Post, id)
      |> Repo.preload([:user_posts, :user, :group, :user_group, :replies])

  def get_reply!(id),
    do: Repo.get!(Reply, id) |> Repo.preload([:user, :post])

  def get_post(id) do
    if :new == id || "new" == id do
      nil
    else
      Repo.get(Post, id)
      |> Repo.preload([
        :user_posts,
        :replies,
        :group,
        :user,
        :replies,
        :user_group,
        :user_post_receipts
      ])
    end
  end

  def get_user_post!(id),
    do: Repo.get!(UserPost, id) |> Repo.preload([:user, :post, :user_post_receipt])

  def get_user_post_receipt!(id),
    do: Repo.get!(UserPostReceipt, id) |> Repo.preload([:user, :user_post])

  def get_user_post_by_post_id_and_user_id!(post_id, user_id) do
    Repo.one!(
      from up in UserPost,
        where: up.post_id == ^post_id,
        where: up.user_id == ^user_id,
        preload: [:post, :user, :user_post_receipt]
    )
  end

  def get_all_shared_posts(user_id) do
    Repo.all(
      from p in Post,
        where: p.user_id == ^user_id,
        where: p.visibility == :connections,
        preload: [:user_posts]
    )
  end

  def get_all_public_user_posts do
    Repo.all(
      from up in UserPost,
        inner_join: p in Post,
        on: up.post_id == p.id,
        where: up.post_id == p.id,
        where: p.visibility == :public,
        preload: [:user, :user_post_receipt, post: :user_posts]
    )
  end

  def get_profile_user_posts(user) do
    Repo.all(
      from up in UserPost,
        inner_join: p in Post,
        on: up.post_id == p.id,
        where: up.post_id == p.id,
        where: p.user_id == ^user.id,
        preload: [:user, :user_post_receipt, post: [:user_posts, :replies, :group, :user_group]]
    )
  end

  @doc """
  Gets the UserPostReceipt for a post and user.
  """
  def get_user_post_receipt(post, current_user) do
    UserPostReceipt
    |> where([upr], upr.user_id == ^current_user.id)
    |> join(:inner, [upr], up in UserPost, on: up.id == upr.user_post_id)
    |> where([upr, up], up.post_id == ^post.id)
    |> where([upr, up], up.user_id == ^current_user.id)
    |> Repo.one()
  end

  @doc """
  Gets the unread post for the user based on the
  associated post through the user_post.
  """
  def get_unread_post_for_user_and_post(post, current_user) do
    Post
    |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
    |> where([p, up], p.id == ^post.id)
    |> where([p, up], up.user_id == ^current_user.id)
    |> join(:inner, [p, up, upr], upr in UserPostReceipt, on: upr.user_post_id == up.id)
    |> where([p, up, upr], upr.user_id == ^current_user.id)
    |> where([p, up, upr], not upr.is_read? and is_nil(upr.read_at))
    |> with_any_visibility([:private, :connections])
    |> preload([:user_posts, :user, :replies, :group, :user_group])
    |> Repo.one()
  end

  @doc """
  Creates a public post.

  ## Examples

      iex> create_public_post(%{field: value})
      {:ok, %Post{}}

      iex> create_public_post(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_public_post(attrs \\ %{}, opts \\ []) do
    post = Post.changeset(%Post{}, attrs, opts)
    user = Accounts.get_user!(opts[:user].id)
    p_attrs = post.changes.user_post_map

    {:ok, %{insert_post: post, insert_user_post: _user_post_conn}} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:insert_post, post)
      |> Ecto.Multi.insert(:insert_user_post, fn %{insert_post: post} ->
        UserPost.changeset(
          %UserPost{},
          %{
            key: p_attrs.temp_key,
            user_id: user.id,
            post_id: post.id
          },
          user: user,
          visibility: attrs["visibility"]
        )
        |> Ecto.Changeset.put_assoc(:post, post)
        |> Ecto.Changeset.put_assoc(:user, user)
      end)
      |> Repo.transaction_on_primary()

    # we do not create multiple user_posts as the post is
    # symmetrically encrypted with the server public key.

    conn = Accounts.get_connection_from_item(post, user)

    {:ok, post}
    |> broadcast_admin(:post_created)

    {:ok, conn, post |> Repo.preload([:user_posts, :group, :user_group, :replies])}
    |> broadcast(:post_created)
  end

  @doc """
  Creates a post.

  ## Examples

      iex> create_post(%{field: value})
      {:ok, %Post{}}

      iex> create_post(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_post(attrs \\ %{}, opts \\ []) do
    post = Post.changeset(%Post{}, attrs, opts)
    user = Accounts.get_user!(opts[:user].id)

    if post.changes[:user_post_map] do
      p_attrs = post.changes.user_post_map

      # "groups" is a single group_id from the live_select single mode component
      if (attrs["groups"] && attrs["groups"] != "") || attrs["group_id"] do
        group =
          if attrs["groups"],
            do: Groups.get_group!(attrs["groups"]),
            else: Groups.get_group!(attrs["group_id"])

        user_group = Groups.get_user_group_for_group_and_user(group, user)

        # we also set the shared users to an empty list as the post
        # is only going to be shared with a group

        attrs =
          attrs
          |> Map.put("group_id", group.id)
          |> Map.put("user_group_id", user_group.id)
          |> Map.put("shared_users", [])

        {:ok, %{insert_post: post, insert_user_post: _user_post_conn}} =
          Ecto.Multi.new()
          |> Ecto.Multi.insert(:insert_post, fn _post ->
            Post.changeset(%Post{}, attrs, opts)
            |> Ecto.Changeset.put_assoc(:group, group)
            |> Ecto.Changeset.put_assoc(:user_group, user_group)
          end)
          |> Ecto.Multi.insert(:insert_user_post, fn %{insert_post: post} ->
            UserPost.changeset(
              %UserPost{},
              %{
                key: p_attrs.temp_key,
                user_id: user.id,
                post_id: post.id
              },
              user: user,
              visibility: attrs["visibility"]
            )
            |> Ecto.Changeset.put_assoc(:post, post)
            |> Ecto.Changeset.put_assoc(:user, user)
          end)
          |> Repo.transaction_on_primary()

        conn = Accounts.get_connection_from_item(post, user)

        # we create user_posts for everyone being shared with
        # create_shared_user_posts(post, attrs, p_attrs, user)

        {:ok, post}
        |> broadcast_admin(:post_created)

        {:ok, conn, post |> Repo.preload([:user_posts, :group, :user_group, :replies])}
        |> broadcast(:post_created)
      else
        case create_new_post(post, user, p_attrs, attrs) do
          # we create user_posts for everyone being shared with
          {:ok, %{insert_post: post, insert_user_post: _user_post_conn}} ->
            create_shared_user_posts(post, attrs, p_attrs, user)

            {:ok, post |> Repo.preload([:user_posts, :replies])}
            |> broadcast_admin(:post_created)

          {:error, insert_post: changeset, insert_user_post: _user_post_changeset} ->
            {:error, changeset}
        end
      end
    else
      # there's an error on the post changeset
      # which we've assigned to this post variable
      {:error, post}
    end
  end

  # wrap the create post in a function so that we can
  # match on a case statement for errors
  defp create_new_post(post, user, p_attrs, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:insert_post, post)
    |> Ecto.Multi.insert(:insert_user_post, fn %{insert_post: post} ->
      UserPost.changeset(
        %UserPost{},
        %{
          key: p_attrs.temp_key,
          user_id: user.id,
          post_id: post.id
        },
        user: user,
        visibility: attrs["visibility"]
      )
      |> Ecto.Changeset.put_assoc(:post, post)
      |> Ecto.Changeset.put_assoc(:user, user)
    end)
    |> Ecto.Multi.insert(:inser_user_post_receipt, fn %{insert_user_post: user_post} ->
      # since this is the user who created the post, we mark it as read
      {:ok, dt} = DateTime.now("Etc/UTC")

      UserPostReceipt.changeset(
        %UserPostReceipt{},
        %{
          user_id: user.id,
          user_post_id: user_post.id,
          is_read?: true,
          read_at: DateTime.to_naive(dt)
        }
      )
      |> Ecto.Changeset.put_assoc(:user, user)
      |> Ecto.Changeset.put_assoc(:user_post, user_post)
    end)
    |> Repo.transaction_on_primary()
  end

  defp create_shared_user_posts(post, attrs, p_attrs, current_user) do
    if attrs["shared_users"] && !Enum.empty?(attrs["shared_users"]) do
      for su <- attrs["shared_users"] do
        user = Mosslet.Accounts.get_user!(su[:user_id] || su["user_id"])

        user_post =
          UserPost.sharing_changeset(
            %UserPost{},
            %{
              key: p_attrs.temp_key,
              post_id: post.id,
              user_id: user.id
            },
            user: user,
            visibility: attrs["visibility"]
          )

        # p_attrs.temp_key is not encrypted yet
        # we also add a user_post_receipt to each person a post is shared with
        # (we don't worry about a receipt for someone who created the post)
        {:ok, %{insert_user_post: _user_post}} =
          Ecto.Multi.new()
          |> Ecto.Multi.insert(:insert_user_post, user_post)
          |> Ecto.Multi.insert(:inser_user_post_receipt, fn %{insert_user_post: user_post} ->
            UserPostReceipt.changeset(
              %UserPostReceipt{},
              %{
                user_id: user.id,
                user_post_id: user_post.id,
                is_read?: false,
                read_at: nil
              }
            )
            |> Ecto.Changeset.put_assoc(:user, user)
            |> Ecto.Changeset.put_assoc(:user_post, user_post)
          end)
          |> Repo.transaction_on_primary()
      end

      conn = Accounts.get_connection_from_item(post, current_user)

      {:ok, conn, post |> Repo.preload([:user_posts, :replies])}
      |> broadcast(:post_created)
    else
      conn = Accounts.get_connection_from_item(post, current_user)

      {:ok, conn, post |> Repo.preload([:user_posts, :replies])}
      |> broadcast(:post_created)
    end
  end

  defp update_shared_user_posts(post, attrs, p_attrs, current_user) do
    if attrs["shared_users"] && !Enum.empty?(attrs["shared_users"]) do
      for su <- attrs["shared_users"] do
        user = Mosslet.Accounts.get_user!(su[:user_id] || su["user_id"])

        user_post =
          UserPost.sharing_changeset(
            get_user_post(post, user),
            %{
              key: p_attrs.temp_key,
              post_id: post.id,
              user_id: user.id
            },
            user: user,
            visibility: attrs["visibility"]
          )

        # p_attrs.temp_key is not encrypted yet

        case Ecto.Multi.new()
             |> Ecto.Multi.update(:update_user_post, user_post)
             |> Repo.transaction_on_primary() do
          {:ok, %{update_user_post: _user_post}} ->
            :ok

          {:error, :update_user_post, changeset, _map} ->
            Logger.warning("Error updating public post")
            Logger.debug("Error updating public post: #{inspect(changeset)}")
            :error

          rest ->
            Logger.warning("Unknown error updating user_post")
            Logger.debug("Unknown error updating user_post: #{inspect(rest)}")
            :error
        end
      end

      conn = Accounts.get_connection_from_item(post, current_user)

      {:ok, conn, post |> Repo.preload([:user_posts, :replies])}
      |> broadcast(:post_updated)
    else
      conn = Accounts.get_connection_from_item(post, current_user)

      {:ok, conn, post |> Repo.preload([:user_posts, :replies])}
      |> broadcast(:post_updated)
    end
  end

  @doc """
  Creates a repost.

  ## Examples

      iex> create_public_repost(%{field: value})
      {:ok, %Post{}}

      iex> create_public_repost(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_public_repost(attrs \\ %{}, opts \\ []) do
    post = Post.repost_changeset(%Post{}, attrs, opts)
    user = Accounts.get_user!(opts[:user].id)
    p_attrs = post.changes.user_post_map

    {:ok, %{insert_post: post, insert_user_post: _user_post_conn}} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:insert_post, post)
      |> Ecto.Multi.insert(:insert_user_post, fn %{insert_post: post} ->
        UserPost.changeset(
          %UserPost{},
          %{
            key: p_attrs.temp_key,
            user_id: user.id,
            post_id: post.id
          },
          user: user,
          visibility: attrs["visibility"] || attrs[:visibility]
        )
        |> Ecto.Changeset.put_assoc(:post, post)
        |> Ecto.Changeset.put_assoc(:user, user)
      end)
      |> Repo.transaction_on_primary()

    # we do not create multiple user_posts as the post is
    # symmetrically encrypted with the server public key.

    conn = Accounts.get_connection_from_item(post, user)

    {:ok, conn, post |> Repo.preload([:user_posts, :replies])}
    |> broadcast(:post_reposted)
  end

  @doc """
  Creates a repost.

  ## Examples

      iex> create_repost(%{field: value})
      {:ok, %Post{}}

      iex> create_repost(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_repost(attrs \\ %{}, opts \\ []) do
    post = Post.repost_changeset(%Post{}, attrs, opts)
    user = Accounts.get_user!(opts[:user].id)
    p_attrs = post.changes.user_post_map

    case Ecto.Multi.new()
         |> Ecto.Multi.insert(:insert_post, post)
         |> Ecto.Multi.insert(:insert_user_post, fn %{insert_post: post} ->
           UserPost.changeset(
             %UserPost{},
             %{
               key: p_attrs.temp_key,
               user_id: user.id,
               post_id: post.id
             },
             user: user,
             visibility: attrs["visibility"] || attrs[:visibility]
           )
           |> Ecto.Changeset.put_assoc(:post, post)
           |> Ecto.Changeset.put_assoc(:user, user)
         end)
         |> Repo.transaction_on_primary() do
      {:ok, %{insert_post: post, insert_user_post: _user_post_conn}} ->
        # we create user_posts for everyone being shared with
        create_shared_user_reposts(post, attrs, p_attrs, user)

      {:error, :insert_post, changeset, _map} ->
        {:error, changeset}

      {:error, :insert_user_post, changeset, _map} ->
        {:error, changeset}

      {:error, :insert_post, _, :update_user_post, changeset, _map} ->
        {:error, changeset}

      rest ->
        Logger.warning("Error creating repost")
        Logger.debug("Error creating repost: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  defp create_shared_user_reposts(post, attrs, p_attrs, current_user) do
    if attrs.shared_users && !Enum.empty?(attrs.shared_users) do
      for su <- attrs.shared_users do
        user = Mosslet.Accounts.get_user!(su[:user_id] || su["user_id"])

        user_post =
          UserPost.sharing_changeset(
            %UserPost{},
            %{
              key: p_attrs.temp_key,
              post_id: post.id,
              user_id: user.id
            },
            user: user,
            visibility: attrs["visibility"]
          )

        # p_attrs.temp_key is not encrypted yet
        {:ok, %{insert_user_post: _user_post}} =
          Ecto.Multi.new()
          |> Ecto.Multi.insert(:insert_user_post, user_post)
          |> Repo.transaction_on_primary()
      end

      conn = Accounts.get_connection_from_item(post, current_user)

      {:ok, conn, post |> Repo.preload([:user_posts, :replies])}
      |> broadcast(:post_reposted)
    else
      conn = Accounts.get_connection_from_item(post, current_user)

      {:ok, conn, post |> Repo.preload([:user_posts, :replies])}
      |> broadcast(:post_reposted)
    end
  end

  @doc """
  Updates a public post.

  ## Examples

      iex> update_public_post(post, %{field: new_value})
      {:ok, %Post{}}

      iex> update_public_post(post, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_public_post(%Post{} = post, attrs, opts \\ []) do
    post = Post.changeset(post, attrs, opts)
    user = Accounts.get_user!(opts[:user].id)
    p_attrs = post.changes.user_post_map

    case Ecto.Multi.new()
         |> Ecto.Multi.update(:update_post, post)
         |> Ecto.Multi.update(:update_user_post, fn %{update_post: post} ->
           UserPost.changeset(
             get_public_user_post(post),
             %{
               key: p_attrs.temp_key,
               user_id: user.id,
               post_id: post.id
             },
             user: user,
             visibility: attrs["visibility"]
           )
           |> Ecto.Changeset.put_assoc(:post, post)
           |> Ecto.Changeset.put_assoc(:user, user)
         end)
         |> Repo.transaction_on_primary() do
      {:ok, %{update_post: post, update_user_post: _user_post_conn}} ->
        # we do not create multiple user_posts as the post is
        # symmetrically encrypted with the server public key.
        conn = Accounts.get_connection_from_item(post, user)

        {:ok, conn, post |> Repo.preload([:user_posts, :replies])}
        |> broadcast(:post_updated)

      {:error, :update_post, changeset, _map} ->
        {:error, changeset}

      {:error, :update_user_post, changeset, _map} ->
        {:error, changeset}

      {:error, :update_post, _, :update_user_post, changeset, _map} ->
        {:error, changeset}

      rest ->
        Logger.warning("Error updating public post")
        Logger.debug("Error updating public post: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  @doc """
  Updates a post.

  ## Examples

      iex> update_post(post, %{field: new_value})
      {:ok, %Post{}}

      iex> update_post(post, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_post(%Post{} = post, attrs, opts \\ []) do
    post = Post.changeset(post, attrs, opts)
    user = Accounts.get_user!(opts[:user].id)

    if post.changes[:user_post_map] do
      p_attrs = post.changes.user_post_map

      case Ecto.Multi.new()
           |> Ecto.Multi.update(:update_post, post)
           |> Ecto.Multi.update(:update_user_post, fn %{update_post: post} ->
             UserPost.changeset(
               get_user_post(post, user),
               %{
                 key: p_attrs.temp_key,
                 user_id: user.id,
                 post_id: post.id
               },
               user: user,
               visibility: attrs["visibility"]
             )
             |> Ecto.Changeset.put_assoc(:post, post)
             |> Ecto.Changeset.put_assoc(:user, user)
           end)
           |> Repo.transaction_on_primary() do
        {:ok, %{update_post: post, update_user_post: _user_post_conn}} ->
          # we create user_posts for everyone being shared with
          # this should return {:ok, post} after the broadcast
          update_shared_user_posts(post, attrs, p_attrs, user)

        {:error, :update_post, changeset, _map} ->
          {:error, changeset}

        {:error, :update_user_post, changeset, _map} ->
          {:error, changeset}

        {:error, :update_post, _, :update_user_post, changeset, _map} ->
          {:error, changeset}

        rest ->
          Logger.warning("Error updating post")
          Logger.debug("Error updating post: #{inspect(rest)}")
          {:error, "error"}
      end
    else
      # there's an error on the post changeset
      # which we've assigned to this post variable
      {:error, post}
    end
  end

  def update_user_post_receipt_read(id) do
    user_post_receipt = get_user_post_receipt!(id)
    {:ok, dt} = DateTime.now("Etc/UTC")
    today = DateTime.to_naive(dt)

    case Repo.transaction_on_primary(fn ->
           UserPostReceipt.changeset(user_post_receipt, %{is_read?: true, read_at: today})
           |> Repo.update()
         end) do
      {:ok, {:ok, user_post_receipt}} ->
        user_post_receipt = Repo.preload(user_post_receipt, [:user_post])
        post = get_post!(user_post_receipt.user_post.post_id)

        conn = Accounts.get_connection_from_item(post, user_post_receipt.user)

        {:ok, conn, post}
        |> broadcast(:post_updated)

      rest ->
        Logger.warning("Error updating post read user_post_receipt")
        Logger.debug("Error updating post read user_post_receipt: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  def update_user_post_receipt_unread(id) do
    user_post_receipt = get_user_post_receipt!(id)

    case Repo.transaction_on_primary(fn ->
           UserPostReceipt.changeset(user_post_receipt, %{is_read?: false, read_at: nil})
           |> Repo.update()
         end) do
      {:ok, {:ok, user_post_receipt}} ->
        user_post_receipt = Repo.preload(user_post_receipt, [:user_post])
        post = get_post!(user_post_receipt.user_post.post_id)

        conn = Accounts.get_connection_from_item(post, user_post_receipt.user)

        {:ok, conn, post}
        |> broadcast(:post_updated)

      rest ->
        Logger.warning("Error updating post unread user_post_receipt")
        Logger.debug("Error updating post unread user_post_receipt: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  def update_post_fav(%Post{} = post, attrs, opts \\ []) do
    user = Accounts.get_user!(opts[:user].id)

    case Repo.transaction_on_primary(fn ->
           Post.favs_changeset(post, attrs, opts)
           |> Repo.update()
         end) do
      {:ok, {:ok, post}} ->
        conn = Accounts.get_connection_from_item(post, user)

        {:ok, conn, post |> Repo.preload([:user_posts, :group, :user_group, :replies])}
        |> broadcast(:post_updated)

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      rest ->
        Logger.warning("Error updating post fav")
        Logger.debug("Error updating post fav: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  def update_post_repost(%Post{} = post, attrs, opts \\ []) do
    user = Accounts.get_user!(opts[:user].id)

    {:ok, {:ok, post}} =
      Repo.transaction_on_primary(fn ->
        Post.change_post_to_repost_changeset(post, attrs, opts)
        |> Repo.update()
      end)

    conn = Accounts.get_connection_from_item(post, user)

    {:ok, conn, post |> Repo.preload([:user_posts, :replies])}
    |> broadcast(:post_updated)
  end

  def update_post_shared_users(%Post{} = post, attrs, opts \\ []) do
    case Repo.transaction_on_primary(fn ->
           Post.change_post_shared_users_changeset(post, attrs, opts)
           |> Repo.update()
         end) do
      {:ok, {:ok, post}} ->
        conn = Accounts.get_connection_from_item(post, opts[:user])

        {:ok, conn, post |> Repo.preload([:user_posts, :replies])}
        |> broadcast(:post_updated)

      {:ok, {:error, changeset}} ->
        Logger.error(
          "There was an error update_post_shared_users/3 in Mosslet.Timeline #{changeset}"
        )

        Logger.debug({inspect(changeset)})
        {:error, changeset}
    end
  end

  @doc """
  Creates a %Reply{}.
  """
  def create_reply(attrs, opts \\ []) do
    user = Accounts.get_user!(opts[:user].id)

    {:ok, {:ok, reply}} =
      Repo.transaction_on_primary(fn ->
        Reply.changeset(%Reply{}, attrs, opts)
        |> Repo.insert()
      end)

    reply = reply |> Repo.preload([:user, :post])
    conn = Accounts.get_connection_from_item(reply.post, user)

    {:ok, conn, reply}
    |> broadcast_reply(:reply_created)
  end

  @doc """
  Updates a %Reply{}.
  """
  def update_reply(%Reply{} = reply, attrs, opts \\ []) do
    user = Accounts.get_user!(opts[:user].id)

    case Repo.transaction_on_primary(fn ->
           Reply.changeset(reply, attrs, opts)
           |> Repo.update()
         end) do
      {:ok, {:ok, reply}} ->
        reply = reply |> Repo.preload([:user, :post])
        conn = Accounts.get_connection_from_item(reply.post, user)

        {:ok, conn, reply}
        |> broadcast_reply(:reply_updated)

      {:ok, {:error, changeset}} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes a %Reply{}.
  """
  def delete_reply(%Reply{} = reply, opts \\ []) do
    user = Accounts.get_user!(opts[:user].id)

    if (user && user.id == reply.user_id) || user.id == reply.post.user_id do
      {:ok, {:ok, reply}} =
        Repo.transaction_on_primary(fn ->
          Repo.delete(reply)
        end)

      conn = Accounts.get_connection_from_item(reply.post, user)

      {:ok, conn, reply}
      |> broadcast_reply(:reply_deleted)
    else
      {:error, "You do not have permission to delete this reply."}
    end
  end

  ## Get UserPost (user_post)

  # The user_post is always just one
  # and is the first in the list
  def get_public_user_post(post) do
    Enum.at(post.user_posts, 0)
    |> Repo.preload([:post, :user, :user_post_receipt])
  end

  def get_user_post(post, user) do
    Repo.one(from up in UserPost, where: up.post_id == ^post.id and up.user_id == ^user.id)
    |> Repo.preload([:post, :user, :user_post_receipt])
  end

  @doc """
  Deletes a post and any reposts.

  ## Examples

      iex> delete_post(post)
      {:ok, %Post{}}

      iex> delete_post(post)
      {:error, %Ecto.Changeset{}}

  """
  def delete_post(%Post{} = post, opts \\ []) do
    if opts[:user] do
      user = Accounts.get_user!(opts[:user].id)
      conn = Accounts.get_connection_from_item(post, user)

      query = from(p in Post, where: p.id == ^post.id or p.original_post_id == ^post.id)

      post =
        Repo.preload(post, [:user_posts, :group, :user_group, :original_post])

      case Repo.transaction_on_primary(fn ->
             Repo.delete_all(query)
           end) do
        {:ok, {:error, changeset}} ->
          {:error, changeset}

        {:ok, {count, _posts}} ->
          if count > 1 do
            {:ok, conn, post}
            |> broadcast(:repost_deleted)
          else
            {:ok, conn, post}
            |> broadcast(:post_deleted)
          end

        rest ->
          Logger.warning("Error deleting post")
          Logger.debug("Error deleting post: #{inspect(rest)}")
          {:error, "error"}
      end
    else
      {:error, "You do not have permission to delete this post."}
    end
  end

  def delete_user_post(%UserPost{} = user_post, opts \\ []) do
    # we get the connection for the user associated with the deleted user_post
    user = Accounts.get_user!(user_post.user_id)

    case Repo.transaction_on_primary(fn ->
           Repo.delete(user_post)
         end) do
      {:ok, {:error, changeset}} ->
        {:error, changeset}

      {:ok, {:ok, user_post}} ->
        post = get_post!(user_post.post_id)

        # remove the shared_user
        shared_user_structs =
          Enum.reject(post.shared_users, fn shared_user ->
            shared_user.id === user.id
          end)

        # convert list from structs to maps
        shared_user_map_list =
          Enum.into(shared_user_structs, [], fn shared_user_struct ->
            Map.from_struct(shared_user_struct)
            |> Map.put(:sender_id, opts[:user].id)
            |> Map.put(:username, opts[:shared_username])
          end)

        # call update_post to remove the user_post_map
        update_post_shared_users(
          post,
          %{
            shared_users: shared_user_map_list
          },
          # is the current_user
          user: opts[:user]
        )

      rest ->
        Logger.warning("Error deleting user_post")
        Logger.debug("Error deleting user_post: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  def delete_group_post(%Post{} = post, opts \\ []) do
    if post.user_id == opts[:user].id || opts[:user_group].role in [:owner, :admin, :moderator] do
      user =
        if post.user_id == opts[:user].id do
          Accounts.get_user!(opts[:user].id)
        else
          Accounts.get_user!(post.user_id)
        end

      conn = Accounts.get_connection_from_item(post, user)

      query = from(p in Post, where: p.id == ^post.id or p.original_post_id == ^post.id)

      post =
        Repo.preload(post, [:user_posts, :group, :user_group, :original_post])

      {:ok, {count, _posts}} =
        Repo.transaction_on_primary(fn ->
          Repo.delete_all(query)
        end)

      if count > 1 do
        {:ok, conn, post}
        |> broadcast(:repost_deleted)
      else
        {:ok, conn, post}
        |> broadcast(:post_deleted)
      end
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.

  ## Examples

      iex> change_post(post)
      %Ecto.Changeset{data: %Post{}}

  """
  def change_post(%Post{} = post, attrs \\ %{}, opts \\ []) do
    Post.changeset(post, attrs, opts)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking reply changes.

  ## Examples

      iex> change_reply(reply)
      %Ecto.Changeset{data: %Reply{}}

  """
  def change_reply(%Reply{} = reply, attrs \\ %{}, opts \\ []) do
    Reply.changeset(reply, attrs, opts)
  end

  def subscribe do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "posts")
  end

  def reply_subscribe do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "replies")
  end

  def private_subscribe(user) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "priv_posts:#{user.id}")
  end

  def private_reply_subscribe(user) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "priv_replies:#{user.id}")
  end

  def connections_subscribe(user) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "conn_posts:#{user.id}")
  end

  def connections_reply_subscribe(user) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "conn_replies:#{user.id}")
  end

  def admin_subscribe(user) do
    if user.is_admin? do
      Phoenix.PubSub.subscribe(Mosslet.PubSub, "admin:posts")
    end
  end

  defp broadcast({:ok, conn, post}, event, _user_conn \\ %{}) do
    case post.visibility do
      :public -> public_broadcast({:ok, post}, event)
      :private -> private_broadcast({:ok, post}, event)
      :connections -> connections_broadcast({:ok, conn, post}, event)
    end
  end

  defp broadcast_reply({:ok, conn, reply}, event, _user_conn \\ %{}) do
    case reply.visibility do
      :public -> public_reply_broadcast({:ok, reply}, event)
      :private -> private_reply_broadcast({:ok, reply}, event)
      :connections -> connections_reply_broadcast({:ok, conn, reply}, event)
    end
  end

  defp broadcast_admin({:ok, struct}, event) do
    Phoenix.PubSub.broadcast(Mosslet.PubSub, "admin:posts", {event, struct})
    {:ok, struct}
  end

  defp public_broadcast({:ok, post}, event) do
    Phoenix.PubSub.broadcast(Mosslet.PubSub, "posts", {event, post})
    {:ok, post}
  end

  defp public_reply_broadcast({:ok, reply}, event) do
    post = get_post!(reply.post_id)

    Phoenix.PubSub.broadcast(Mosslet.PubSub, "replies", {event, post, reply})

    {:ok, reply}
  end

  defp private_broadcast({:ok, post}, event) do
    Phoenix.PubSub.broadcast(Mosslet.PubSub, "priv_posts:#{post.user_id}", {event, post})
    {:ok, post}
  end

  defp private_reply_broadcast({:ok, reply}, event) do
    post = get_post!(reply.post_id)

    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "priv_replies:#{reply.user_id}",
      {event, post, reply}
    )

    {:ok, reply}
  end

  defp connections_broadcast({:ok, conn, post}, event) do
    # we only broadcast to our connections if it's NOT a group post
    if is_nil(post.group_id) do
      Enum.each(conn.user_connections, fn uconn ->
        Enum.each(post.shared_users, fn _shared_user ->
          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "conn_posts:#{uconn.reverse_user_id}",
            {event, post}
          )

          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "conn_posts:#{uconn.user_id}",
            {event, post}
          )
        end)
      end)

      {:ok, post}
    else
      maybe_publish_group_post({event, post})
    end
  end

  defp connections_reply_broadcast({:ok, conn, reply}, event) do
    post = get_post!(reply.post_id)

    # we only broadcast to our connections if it's NOT a group post
    if is_nil(post.group_id) do
      Enum.each(conn.user_connections, fn uconn ->
        Enum.each(post.shared_users, fn _shared_user ->
          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "conn_replies:#{uconn.user_id}",
            {event, post, reply}
          )

          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "conn_replies:#{uconn.reverse_user_id}",
            {event, post, reply}
          )
        end)
      end)

      {:ok, reply}
    else
      maybe_publish_group_post_reply({event, post, reply})
    end
  end

  defp maybe_publish_group_post({event, post}) do
    if not is_nil(post.group_id) do
      publish_group_post({event, post})
    end
  end

  defp maybe_publish_group_post_reply({event, post, reply}) do
    if not is_nil(post.group_id) do
      publish_group_post_reply({event, post, reply})
    end
  end

  ##  Group Post broadcasts

  def publish_group_post({event, post}) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "group:#{post.group_id}",
      {event, post}
    )

    {:ok, post}
  end

  def publish_group_post_reply({event, post, reply}) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "group:#{post.group_id}",
      {event, post, reply}
    )

    {:ok, reply}
  end
end

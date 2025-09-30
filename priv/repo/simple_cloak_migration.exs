# Simple Cloak Migration for Post Interactions
# Run in IEx: 

alias Mosslet.Timeline.Post
alias Mosslet.Repo.Local, as: Repo

Post
|> Repo.all()
|> Enum.map(fn post ->
  post
  |> Ecto.Changeset.change(%{
    encrypted_favs_list: post.favs_list,
    encrypted_reposts_list: post.reposts_list
  })
  |> Repo.update!()
end)
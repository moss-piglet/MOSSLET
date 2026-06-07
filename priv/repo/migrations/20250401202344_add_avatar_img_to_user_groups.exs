defmodule Mosslet.Repo.Migrations.AddAvatarImgToUserGroups do
  use Ecto.Migration

  def change do
    alter table(:user_groups) do
      add :avatar_img, :binary
    end
  end
end

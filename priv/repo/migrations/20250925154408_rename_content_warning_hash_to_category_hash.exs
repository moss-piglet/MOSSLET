defmodule Mosslet.Repo.Local.Migrations.RenameContentWarningHashToCategoryHash do
  use Ecto.Migration

  def change do
    rename table(:posts), :content_warning_hash, to: :content_warning_category_hash
  end
end

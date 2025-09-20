defmodule Mosslet.Repo.Local.Migrations.RenameContentWarningFields do
  use Ecto.Migration

  def change do
    # Rename content warning fields to follow Elixir best practices
    rename table(:posts), :content_warning_text, to: :content_warning
    rename table(:posts), :has_content_warning, to: :content_warning?
  end
end

defmodule Mosslet.Repo.Migrations.CreateUserPostReports do
  use Ecto.Migration

  def change do
    create table(:user_post_reports, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :binary, null: false

      add :post_report_id, references(:post_reports, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps()
    end

    create unique_index(:user_post_reports, [:post_report_id])
  end
end

defmodule Mosslet.Repo.Local.Migrations.AddAiTokensToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :ai_tokens, :decimal
      add :ai_tokens_used, :decimal
    end
  end
end

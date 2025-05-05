defmodule Beam.Repo.Migrations.AddTypeAndDifficultyToRecommendations do
  use Ecto.Migration

  def change do
    alter table(:recommendations) do
      add :type, :string
      add :difficulty, :string
    end
  end
end

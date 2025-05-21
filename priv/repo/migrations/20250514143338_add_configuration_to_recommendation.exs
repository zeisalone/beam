defmodule Beam.Repo.Migrations.AddConfigurationToRecommendation do
  use Ecto.Migration

  def change do
    alter table(:recommendations) do
      add :configuration_id, references(:exercise_configurations, on_delete: :nilify_all)
    end
  end
end

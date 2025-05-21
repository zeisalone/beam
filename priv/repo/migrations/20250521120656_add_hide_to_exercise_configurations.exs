defmodule Beam.Repo.Migrations.AddHideToExerciseConfigurations do
  use Ecto.Migration

  def change do
    alter table(:exercise_configurations) do
      add :hide, :boolean, default: false
    end
  end
end

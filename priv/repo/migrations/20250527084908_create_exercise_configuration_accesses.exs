defmodule Beam.Repo.Migrations.CreateExerciseConfigurationAccesses do
  use Ecto.Migration

  def change do
    create table(:exercise_configuration_accesses) do
      add :patient_id, references(:patients, column: :patient_id, type: :string, on_delete: :delete_all)
      add :configuration_id, references(:exercise_configurations, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:exercise_configuration_accesses, [:patient_id, :configuration_id])
  end
end

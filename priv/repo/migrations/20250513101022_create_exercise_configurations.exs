defmodule Beam.Repo.Migrations.CreateExerciseConfigurations do
  use Ecto.Migration

  def change do
    create table(:exercise_configurations) do
      add :task_id, references(:tasks, on_delete: :delete_all), null: false
      add :therapist_id, :string, null: false

      add :name, :string, null: false
      add :data, :map, null: false
      add :public, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:exercise_configurations, [:task_id])
    create index(:exercise_configurations, [:therapist_id])
  end
end

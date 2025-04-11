defmodule Beam.Repo.Migrations.CreateExercicesSupportTables do
  use Ecto.Migration

  def change do
    # Results
    create table(:results) do
      add :correct, :integer
      add :wrong, :integer
      add :omitted, :integer
      add :accuracy, :float
      add :reaction_time, :float
      add :task_id, references(:tasks, on_delete: :nothing)
      add :user_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:results, [:task_id])
    create index(:results, [:user_id])

    # Trainings
    create table(:trainings) do
      add :attempt_number, :integer, default: 1
      add :difficulty, :string
      add :task_id, references(:tasks, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :result_id, references(:results, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:trainings, [:task_id])
    create index(:trainings, [:user_id])
    create index(:trainings, [:result_id])

    # Tests
    create table(:tests) do
      add :attempt_number, :integer, default: 1
      add :task_id, references(:tasks, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :result_id, references(:results, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:tests, [:task_id])
    create index(:tests, [:user_id])
    create index(:tests, [:result_id])

    # Recommendations
    create table(:recommendations) do
      add :task_id, references(:tasks, on_delete: :delete_all)

      add :patient_id,
          references(:patients, column: :patient_id, type: :string, on_delete: :delete_all)

      add :therapist_id,
          references(:therapists, column: :therapist_id, type: :string, on_delete: :delete_all)

      add :seen, :boolean, default: false

      timestamps()
    end

    # Notes
    create table(:notes) do
      add :description, :text, null: false

      add :therapist_id,
          references(:therapists, column: :therapist_id, type: :string, on_delete: :delete_all)

      add :patient_id,
          references(:patients, column: :patient_id, type: :string, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end
  end
end

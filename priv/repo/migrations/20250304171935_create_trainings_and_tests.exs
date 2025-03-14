defmodule Beam.Repo.Migrations.CreateTrainingsAndTests do
  use Ecto.Migration

  def change do
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
  end
end

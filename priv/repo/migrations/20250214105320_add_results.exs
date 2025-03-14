defmodule Beam.Repo.Migrations.AddResults do
  use Ecto.Migration

  def change do
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
  end
end

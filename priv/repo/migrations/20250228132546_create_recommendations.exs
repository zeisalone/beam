defmodule Beam.Repo.Migrations.CreateRecommendations do
  use Ecto.Migration

  def change do
    create table(:recommendations) do
      add :task_id, references(:tasks, on_delete: :delete_all)

      add :patient_id,
          references(:patients, column: :patient_id, type: :string, on_delete: :delete_all)

      add :therapist_id,
          references(:therapists, column: :therapist_id, type: :string, on_delete: :delete_all)

      add :seen, :boolean, default: false

      timestamps()
    end
  end
end

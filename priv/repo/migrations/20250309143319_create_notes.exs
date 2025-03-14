defmodule Beam.Repo.Migrations.CreateNotes do
  use Ecto.Migration

  def change do
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

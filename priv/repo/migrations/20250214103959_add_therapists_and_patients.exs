defmodule Beam.Repo.Migrations.AddTherapistsAndPatients do
  use Ecto.Migration

  def change do
    create table(:therapists) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :therapist_id, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:therapists, [:therapist_id])

    create table(:patients) do
      add :user_id, references(:users, on_delete: :delete_all), null: false

      add :therapist_id,
          references(:therapists, column: :therapist_id, type: :string, on_delete: :delete_all),
          null: false

      add :patient_id, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:patients, [:patient_id])
  end
end

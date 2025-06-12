defmodule Beam.Repo.Migrations.AddSpecializationToTherapists do
  use Ecto.Migration

  def up do
    alter table(:therapists) do
      add :specialization, :string, null: false, default: "Terapeuta"
    end

    execute("""
    UPDATE therapists
    SET specialization = 'Terapeuta'
    WHERE specialization IS NULL OR specialization = ''
    """)
  end

  def down do
    alter table(:therapists) do
      remove :specialization
    end
  end
end

defmodule Beam.Repo.Migrations.AddGenderAndEducationToPatients do
  use Ecto.Migration

  def change do
    alter table(:patients) do
      add :gender, :string, default: "Masculino", null: false
      add :education_level, :string, default: "Pré-Primaria", null: false
    end
  end
end

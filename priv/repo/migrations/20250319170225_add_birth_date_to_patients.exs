defmodule Beam.Repo.Migrations.AddBirthDateToPatients do
  use Ecto.Migration

  def change do
    alter table(:patients) do
      add :birth_date, :date
    end

    execute "UPDATE patients SET birth_date = '1980-01-01' WHERE birth_date IS NULL"

    alter table(:patients) do
      modify :birth_date, :date, null: false
    end
  end
end

defmodule Beam.Repo.Migrations.AddFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :name, :string
      add :type, :string
    end

    create constraint(:users, :valid_user_type,
             check: "type IN ('Paciente', 'Terapeuta', 'Admin')"
           )
  end
end

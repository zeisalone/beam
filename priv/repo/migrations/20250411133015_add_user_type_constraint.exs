defmodule Beam.Repo.Migrations.AddUserTypeConstraint do
  use Ecto.Migration

  def change do
    create constraint(:users, :valid_user_type,
      check: "type IN ('Paciente', 'Terapeuta', 'Admin')"
    )
  end
end

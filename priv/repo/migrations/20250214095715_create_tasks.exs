defmodule Beam.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks) do
      add :name, :string
      add :type, :string

      timestamps(type: :utc_datetime)
    end
  end
end

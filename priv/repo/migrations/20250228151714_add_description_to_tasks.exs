defmodule Beam.Repo.Migrations.AddDescriptionToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :description, :text
    end
  end
end

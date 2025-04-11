defmodule Beam.Repo.Migrations.CreateTasksTable do
  use Ecto.Migration

  def change do
    create table(:tasks) do
      add :name, :string
      add :type, :string
      add :description, :text
      add :image_path, :string
      add :tags, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end
  end
end

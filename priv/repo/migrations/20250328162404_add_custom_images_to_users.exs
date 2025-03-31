defmodule Beam.Repo.Migrations.AddCustomImagesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :custom_images, {:array, :string}, default: [], null: false
    end
  end
end

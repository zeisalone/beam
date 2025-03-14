defmodule Beam.Repo.Migrations.AddProfileImageToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :profile_image, :string, default: "images/profile/profile.svg"
    end
  end
end

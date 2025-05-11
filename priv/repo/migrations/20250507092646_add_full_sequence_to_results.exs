defmodule Beam.Repo.Migrations.AddFullSequenceToResults do
  use Ecto.Migration

  def change do
    alter table(:results) do
      add :full_sequence, :integer
    end
  end
end

defmodule Beam.Exercices.Task do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tasks" do
    field :name, :string
    field :type, :string
    field :description, :string

    has_many :trainings, Beam.Exercices.Training
    has_many :tests, Beam.Exercices.Test

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(task, attrs) do
    task
    |> cast(attrs, [:name, :type, :description])
    |> validate_required([:name, :type, :description])
  end
end

defmodule Beam.Exercices.Task do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tasks" do
    field :name, :string
    field :type, :string
    field :description, :string
    field :image_path, :string
    field :tags, {:array, :string}, default: []

    has_many :trainings, Beam.Exercices.Training
    has_many :tests, Beam.Exercices.Test

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(task, attrs) do
    task
    |> cast(attrs, [:name, :type, :description, :image_path, :tags])
    |> validate_required([:name, :type, :description])
  end
end

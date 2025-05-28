defmodule Beam.Exercices.ExerciseConfiguration do
  use Ecto.Schema
  import Ecto.Changeset

  schema "exercise_configurations" do
    field :name, :string
    field :data, :map
    field :public, :boolean, default: false
    field :therapist_id, :string
    field :hide, :boolean, default: false

    belongs_to :task, Beam.Exercices.Task
    has_many :accesses, Beam.Exercices.ExerciseConfigurationAccess, foreign_key: :configuration_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(config, attrs) do
    config
    |> cast(attrs, [:name, :data, :public, :task_id, :therapist_id, :hide])
    |> validate_required([:name, :data, :task_id, :therapist_id])
  end
end

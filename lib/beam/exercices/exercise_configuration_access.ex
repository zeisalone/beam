defmodule Beam.Exercices.ExerciseConfigurationAccess do
  use Ecto.Schema
  import Ecto.Changeset

  schema "exercise_configuration_accesses" do
    field :patient_id, :string

    belongs_to :configuration, Beam.Exercices.ExerciseConfiguration
    belongs_to :patient, Beam.Accounts.Patient, references: :patient_id, define_field: false, type: :string

    timestamps(type: :utc_datetime)
  end

  def changeset(access, attrs) do
    access
    |> cast(attrs, [:patient_id, :configuration_id])
    |> validate_required([:patient_id, :configuration_id])
    |> unique_constraint([:patient_id, :configuration_id])
  end
end

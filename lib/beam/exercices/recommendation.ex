defmodule Beam.Exercices.Recommendation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "recommendations" do
    belongs_to :task, Beam.Exercices.Task
    belongs_to :patient, Beam.Accounts.Patient, references: :patient_id, type: :string
    belongs_to :therapist, Beam.Accounts.Therapist, references: :therapist_id, type: :string

    field :seen, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def changeset(recommendation, attrs) do
    recommendation
    |> cast(attrs, [:task_id, :patient_id, :therapist_id, :seen])
    |> validate_required([:task_id, :patient_id, :therapist_id])
  end
end

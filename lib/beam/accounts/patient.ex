defmodule Beam.Accounts.Patient do
  use Ecto.Schema
  import Ecto.Changeset

  schema "patients" do
    field :patient_id, :string
    belongs_to :user, Beam.Accounts.User
    belongs_to :therapist, Beam.Accounts.Therapist, references: :therapist_id, type: :string

    timestamps(type: :utc_datetime)
  end

  def changeset(patient, attrs) do
    patient
    |> cast(attrs, [:patient_id, :user_id, :therapist_id])
    |> validate_required([:patient_id, :user_id, :therapist_id])
    |> unique_constraint(:patient_id)
  end
end

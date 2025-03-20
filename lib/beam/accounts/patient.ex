defmodule Beam.Accounts.Patient do
  use Ecto.Schema
  import Ecto.Changeset

  schema "patients" do
    field :patient_id, :string
    field :birth_date, :date, default: ~D[1980-01-01]
    belongs_to :user, Beam.Accounts.User
    belongs_to :therapist, Beam.Accounts.Therapist, references: :therapist_id, type: :string

    timestamps(type: :utc_datetime)
  end

  def changeset(patient, attrs) do
    patient
    |> cast(attrs, [:patient_id, :user_id, :therapist_id, :birth_date])
    |> validate_required([:patient_id, :user_id, :therapist_id, :birth_date])
    |> unique_constraint(:patient_id)
  end
end

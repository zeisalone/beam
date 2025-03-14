defmodule Beam.Accounts.Note do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notes" do
    field :description, :string
    belongs_to :therapist, Beam.Accounts.Therapist, references: :therapist_id, type: :string
    belongs_to :patient, Beam.Accounts.Patient, references: :patient_id, type: :string

    timestamps(type: :utc_datetime)
  end

  def changeset(note, attrs) do
    note
    |> cast(attrs, [:description, :therapist_id, :patient_id])
    |> validate_required([:description, :therapist_id, :patient_id])
  end
end

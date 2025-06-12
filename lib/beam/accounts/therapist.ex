defmodule Beam.Accounts.Therapist do
  use Ecto.Schema
  import Ecto.Changeset

  schema "therapists" do
    field :therapist_id, :string
    field :specialization, :string, default: "Terapeuta"
    belongs_to :user, Beam.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(therapist, attrs) do
    therapist
    |> cast(attrs, [:therapist_id, :user_id, :specialization])
    |> validate_required([:therapist_id, :user_id, :specialization])
    |> validate_length(:specialization, max: 40)
    |> unique_constraint(:therapist_id)
  end
end

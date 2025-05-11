defmodule Beam.Exercices.Result do
  use Ecto.Schema
  import Ecto.Changeset

  schema "results" do
    field :correct, :integer
    field :wrong, :integer
    field :omitted, :integer
    field :accuracy, :float
    field :reaction_time, :float
    field :full_sequence, :integer
    belongs_to :task, Beam.Exercices.Task
    belongs_to :user, Beam.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(result, attrs) do
    result
    |> cast(attrs, [:correct, :wrong, :omitted, :accuracy, :reaction_time, :task_id, :user_id, :full_sequence])
    |> validate_required([:correct, :wrong, :accuracy, :reaction_time, :task_id, :user_id])
  end
end

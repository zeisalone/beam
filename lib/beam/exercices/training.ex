defmodule Beam.Exercices.Training do
  use Ecto.Schema
  import Ecto.Changeset

  schema "trainings" do
    field :attempt_number, :integer, default: 1
    field :difficulty, Ecto.Enum, values: [:facil, :medio, :dificil, :criado]

    belongs_to :task, Beam.Exercices.Task
    belongs_to :result, Beam.Exercices.Result, foreign_key: :result_id
    belongs_to :user, Beam.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(training, attrs) do
    training
    |> cast(attrs, [:attempt_number, :difficulty, :task_id, :result_id, :user_id])
    |> validate_required([:attempt_number, :difficulty, :task_id, :result_id, :user_id])
    |> assoc_constraint(:task)
    |> assoc_constraint(:result)
    |> assoc_constraint(:user)
  end
end

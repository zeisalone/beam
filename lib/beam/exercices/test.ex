defmodule Beam.Exercices.Test do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tests" do
    field :attempt_number, :integer, default: 1

    belongs_to :task, Beam.Exercices.Task
    belongs_to :result, Beam.Exercices.Result, foreign_key: :result_id
    belongs_to :user, Beam.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(test, attrs) do
    test
    |> cast(attrs, [:attempt_number, :task_id, :result_id, :user_id])
    |> validate_required([:attempt_number, :task_id, :result_id, :user_id])
    |> assoc_constraint(:task)
    |> assoc_constraint(:result)
    |> assoc_constraint(:user)
  end
end

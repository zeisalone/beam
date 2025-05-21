defmodule Beam.Exercices.Recommendation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "recommendations" do
    belongs_to :task, Beam.Exercices.Task
    belongs_to :patient, Beam.Accounts.Patient, references: :patient_id, type: :string
    belongs_to :therapist, Beam.Accounts.Therapist, references: :therapist_id, type: :string
    belongs_to :configuration, Beam.Exercices.ExerciseConfiguration

    field :type, Ecto.Enum, values: [:treino, :teste]
    field :difficulty, Ecto.Enum, values: [:facil, :medio, :dificil, :criado]
    field :seen, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def changeset(recommendation, attrs) do
    recommendation
    |> cast(attrs, [:task_id, :patient_id, :therapist_id, :type, :difficulty, :seen, :configuration_id])
    |> validate_required([:task_id, :patient_id, :therapist_id, :type])
    |> validate_inclusion(:difficulty, [:facil, :medio, :dificil, :criado])
    |> validate_difficulty_only_for_treino()
    |> validate_configuration_for_criado()
  end

  defp validate_difficulty_only_for_treino(changeset) do
    if get_field(changeset, :type) == :teste and get_field(changeset, :difficulty) do
      add_error(changeset, :difficulty, "não deve ser definida para testes")
    else
      changeset
    end
  end

  defp validate_configuration_for_criado(changeset) do
    if get_field(changeset, :difficulty) == :criado and is_nil(get_field(changeset, :configuration_id)) do
      add_error(changeset, :configuration_id, "deve ser especificado para dificuldades criadas")
    else
      changeset
    end
  end
end

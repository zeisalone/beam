defmodule Beam.Exercices.Tasks.SearchingForAVowel do
  @behaviour Beam.Exercices.Configurable
  alias Beam.Accounts.Patient
  alias Beam.Repo
  @moduledoc """
  Logic for the Searching for the Vowel task.
  """

  @vowels ["A", "E", "I", "O", "U"]
  @colors ["red", "blue", "green", "yellow"]
  @positions ["up", "down", "left", "right"]

  def default_config do
    %{
      phase_duration: 3000,
      cycle_duration: 2000,
      total_phases: 20,
      num_distractors_list: [1,2,3]
    }
  end

  def config_spec do
    [
      {:phase_duration, :integer, label: "Duração da fase (ms)"},
      {:cycle_duration, :integer, label: "Duração entre fases (ms)"},
      {:total_phases, :integer, label: "Número total de fases"},
      {:num_distractors_list, :select, label: "Número de Distratores", options: [
        "1", "2", "3", "1,2", "2,3", "1,2,3"
      ], multiple: false}
    ]
  end

  def validate_config(%{phase_duration: phase, cycle_duration: cycle, total_phases: total, num_distractors_list: ndlist})
      when is_integer(phase) and phase > 0 and
           is_integer(cycle) and cycle > 0 and
           is_integer(total) and total > 0 and
           (is_binary(ndlist) or is_list(ndlist)) do
    :ok
  end

  def validate_config(_),
    do: {:error, %{message: "Parâmetros inválidos! Verifique a configuração."}}

  def get_patient_age(user_id) do
    case Repo.get_by(Patient, user_id: user_id) do
      %Patient{birth_date: birth_date} when not is_nil(birth_date) ->
        today = Date.utc_today()
        years = Date.diff(today, birth_date) |> div(365)
        {:ok, max(years, 0)}
      _ -> :error
    end
  end

  def choose_level_by_age(user_id) do
    case get_patient_age(user_id) do
      {:ok, age} when is_integer(age) and age <= 10 -> :facil
      {:ok, age} when is_integer(age) and age >= 11 -> :medio
      _ -> :medio
    end
  end

  @doc """
  Generate the target vowel and color.
  """
  def generate_target do
    %{
      vowel: Enum.random(@vowels),
      color: Enum.random(@colors)
    }
  end

  @doc """
  Generate a phase with the target and random distractors.
  """
  def generate_phase(target, difficulty, config \\ %{}) do
    positions = Enum.shuffle(@positions)

    num_distractors =
      case difficulty do
        :facil -> 1
        :medio -> Enum.random([1, 2])
        :dificil -> Enum.random([2, 3])
        :criado ->
          config
          |> Map.get(:num_distractors_list, "1,2,3")
          |> to_distractor_list()
          |> Enum.random()
        _ -> Enum.random([1, 2, 3])
      end

    distractors =
      1..num_distractors
      |> Enum.map(fn i ->
        generate_distractor(target, Enum.at(positions, i), difficulty)
      end)

    [Map.put(target, :position, Enum.at(positions, 0)) | distractors]
  end

  defp to_distractor_list(list) when is_list(list), do: list
  defp to_distractor_list(val) when is_integer(val), do: [val]
  defp to_distractor_list(val) when is_binary(val) do
    val
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_integer/1)
  end
  defp to_distractor_list(_), do: [1,2,3]

  defp generate_distractor(target, position, difficulty) do
    vowel_options = @vowels -- [target.vowel]
    color_options = @colors -- [target.color]

    case difficulty do
      :facil ->
        %{
          vowel: Enum.random(vowel_options),
          color: Enum.random(color_options),
          position: position
        }

      :medio ->
        case Enum.random([
               :same_color_diff_vowel,
               :same_color_diff_vowel,
               :same_vowel_diff_color,
               :completely_different
             ]) do
          :same_vowel_diff_color ->
            %{
              vowel: target.vowel,
              color: Enum.random(color_options),
              position: position
            }

          :same_color_diff_vowel ->
            %{
              vowel: Enum.random(vowel_options),
              color: target.color,
              position: position
            }

          :completely_different ->
            %{
              vowel: Enum.random(vowel_options),
              color: Enum.random(color_options),
              position: position
            }
        end

      :dificil ->
        prob = Enum.random(1..100)

        cond do
          prob <= 50 ->
            %{
              vowel: target.vowel,
              color: Enum.random(color_options),
              position: position
            }

          prob <= 85 ->
            %{
              vowel: Enum.random(vowel_options),
              color: target.color,
              position: position
            }

          true ->
            %{
              vowel: Enum.random(vowel_options),
              color: Enum.random(color_options),
              position: position
            }
        end

      :criado ->
        generate_distractor(target, position, :dificil)

      _ ->
        generate_distractor(target, position, :medio)
    end
  end

  @doc """
  Validate the user's response.
  """
  def validate_response(clicked, target) do
    if clicked.vowel == target.vowel and clicked.color == target.color do
      :correct
    else
      :wrong
    end
  end

  @doc """
  Calculate accuracy.
  """
  def calculate_accuracy(correct, wrong, omitted) do
    total = correct + wrong + omitted

    if total > 0 do
      Float.round(correct / total * 100, 2)
    else
      0.0
    end
  end

  @doc """
  Create a result entry for DB.
  """
  def create_result_entry(user_id, task_id, correct, wrong, omitted, reaction_time) do
    accuracy = calculate_accuracy(correct, wrong, omitted)

    %{
      user_id: user_id,
      task_id: task_id,
      correct: correct,
      wrong: wrong,
      omitted: omitted,
      accuracy: accuracy,
      reaction_time: reaction_time
    }
  end
end

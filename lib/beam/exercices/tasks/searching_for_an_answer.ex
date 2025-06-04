defmodule Beam.Exercices.Tasks.SearchingForAnAnswer do
  @behaviour Beam.Exercices.Configurable
  @moduledoc """
  Logic for the Searching for an Answer task.
  """

  @shapes ["circle", "square", "triangle", "star", "heart"]
  @colors ["red", "blue", "green", "yellow"]
  @positions ["up", "down", "left", "right"]


  def default_config do
    %{
      phase_duration: 3000,
      cycle_duration: 2000,
      total_phases: 20,
      num_distractors_list: [1, 2, 3]
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


  def validate_config(%{
      phase_duration: phase,
      cycle_duration: cycle,
      total_phases: total,
      num_distractors_list: ndlist
    })
      when is_integer(phase) and is_integer(cycle) and is_integer(total) and
            phase > 0 and cycle > 0 and total > 0 and
            (is_list(ndlist) or is_binary(ndlist)) do
    :ok
  end

  def validate_config(_),
    do: {:error, %{message: "Parâmetros inválidos: verifique a configuração."}}

  @doc """
  Generate the target shape and color for the task.
  """
  def generate_target do
    %{
      shape: Enum.random(@shapes),
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
        :medio -> Enum.random([1,2])
        :dificil -> Enum.random([2,3])
        :criado ->
          config
          |> Map.get(:num_distractors_list, "1,2,3")
          |> to_distractor_list()
          |> Enum.random()
        _ -> Enum.random([1,2,3])
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
  defp to_distractor_list(_), do: [1, 2, 3]

  defp generate_distractor(target, position, difficulty) do
    shape_options = @shapes -- [target.shape]
    color_options = @colors -- [target.color]

    case difficulty do
      :facil ->
        %{
          shape: Enum.random(shape_options),
          color: Enum.random(color_options),
          position: position
        }

      :medio ->
        case Enum.random([:same_color_diff_shape, :same_color_diff_shape, :same_shape_diff_color, :completely_different]) do
          :same_shape_diff_color ->
            %{
              shape: target.shape,
              color: Enum.random(color_options),
              position: position
            }

          :same_color_diff_shape ->
            %{
              shape: Enum.random(shape_options),
              color: target.color,
              position: position
            }

          :completely_different ->
            %{
              shape: Enum.random(shape_options),
              color: Enum.random(color_options),
              position: position
            }
        end

      :dificil ->
        probabilidade = Enum.random(1..100)

        cond do
          probabilidade <= 50 ->
            %{
              shape: target.shape,
              color: Enum.random(color_options),
              position: position
            }

          probabilidade <= 85 ->
            %{
              shape: Enum.random(shape_options),
              color: target.color,
              position: position
            }

          true ->
            %{
              shape: Enum.random(shape_options),
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
  def validate_response(user_response, target) do
    if user_response == target.position do
      :correct
    else
      :wrong
    end
  end

  @doc """
  Calculate accuracy for the task.
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
  Create a result entry for a phase.
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

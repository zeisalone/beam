defmodule Beam.Exercices.Tasks.FollowTheFigure do
  @moduledoc """
  Lógica para o exercício "Segue a Forma".
  """

  @shapes ["circle", "square", "triangle", "star", "heart"]
  @colors ["red", "blue", "green", "yellow", "purple", "orange"]

  def generate_round(round_index, difficulty) do
    target = %{
      shape: Enum.random(@shapes),
      color: Enum.random(@colors)
    }

    if round_index <= 2 do
      distractors =
        1..8
        |> Enum.map(fn _ ->
          Map.put(generate_distractor(target, Enum.random(@colors -- [target.color])), :layout, :center_block)
        end)

      target_with_layout = Map.put(target, :layout, :center_block)
      figures = Enum.shuffle([target_with_layout | distractors])

      %{
        figures: figures,
        target: target_with_layout,
        moving: false,
        overlap: false
      }
    else
      distractors = generate_distractors(target, round_index, difficulty)
      figures = Enum.shuffle([target | distractors])

      %{
        figures: figures,
        target: target,
        moving: should_move?(difficulty),
        overlap: should_overlap?(difficulty, round_index)
      }
    end
  end

  defp generate_distractors(target, round_index, difficulty) do
    count =
      case difficulty do
        :facil -> Enum.random(8..12)
        :medio -> Enum.random(30..70)
        :dificil -> Enum.random(90..150)
      end

      color_bias =
        case difficulty do
          :facil ->
            Enum.shuffle(
              List.duplicate(@colors -- [target.color], ceil(count / 5))
              |> List.flatten()
              |> Enum.take(count)
            )

          :medio ->
            percent = Enum.random(30..45) / 100
            same_color_count = round(count * percent)
            other_color_count = count - same_color_count

            same_colors = List.duplicate(target.color, same_color_count)
            other_colors_pool = @colors -- [target.color]

            other_colors =
              Stream.cycle(other_colors_pool)
              |> Enum.take(other_color_count)

            Enum.shuffle(same_colors ++ other_colors)

          :dificil ->
            percent = Enum.random(50..65) / 100
            same_color_count = round(count * percent)
            other_color_count = count - same_color_count

            same_colors = List.duplicate(target.color, same_color_count)
            other_colors_pool = @colors -- [target.color]

            other_colors =
              Stream.cycle(other_colors_pool)
              |> Enum.take(other_color_count)

            Enum.shuffle(same_colors ++ other_colors)
        end


    1..count
    |> Enum.map(fn i ->
      distractor = generate_distractor(target, Enum.at(color_bias, rem(i - 1, length(color_bias))))

      if round_index <= 2 do
        Map.put(distractor, :layout, :center_block)
      else
        distractor
      end
    end)
  end

  defp generate_distractor(%{shape: target_shape, color: target_color}, distractor_color) do
    distractor_color =
      if is_nil(distractor_color) do
        Enum.random(@colors -- [target_color])
      else
        distractor_color
      end

    shape = Enum.random(@shapes -- [target_shape])

    if shape == target_shape and distractor_color == target_color do
      generate_distractor(%{shape: target_shape, color: target_color}, distractor_color)
    else
      %{shape: shape, color: distractor_color}
    end
  end

  defp should_move?(:facil), do: false
  defp should_move?(:medio), do: :rand.uniform() < 0.4
  defp should_move?(:dificil), do: :rand.uniform() < 0.75

  defp should_overlap?(_difficulty, round) when round <= 2, do: false
  defp should_overlap?(:facil, _), do: :rand.uniform() < 0.15
  defp should_overlap?(:medio, _), do: :rand.uniform() < 0.4
  defp should_overlap?(:dificil, _), do: :rand.uniform() < 0.75

  def validate_selection(%{shape: shape, color: color}, target) do
    if shape == target.shape and color == target.color, do: :correct, else: :wrong
  end

  def calculate_accuracy(correct, wrong, omitted) do
    total = correct + wrong + omitted
    if total > 0, do: Float.round(correct / total * 100, 2), else: 0.0
  end

  def create_result_entry(user_id, task_id, correct, wrong, omitted, total_reaction_time) do
    total = correct + wrong + omitted
    avg_reaction_time = if total > 0, do: total_reaction_time / total, else: 0

    %{
      user_id: user_id,
      task_id: task_id,
      correct: correct,
      wrong: wrong,
      omitted: omitted,
      accuracy: calculate_accuracy(correct, wrong, omitted),
      reaction_time: avg_reaction_time
    }
  end
end

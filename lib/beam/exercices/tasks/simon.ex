defmodule Beam.Exercices.Tasks.Simon do
  @moduledoc """
  Lógica para o exercício do tipo Simon.
  """

  @colors ["red", "blue", "green", "yellow", "purple", "orange", "teal", "pink", "brown"]

  def generate_colors(difficulty) do
    count =
      case difficulty do
        :facil -> 4
        :medio -> 6
        :dificil -> 9
      end

    Enum.take_random(@colors, count)
  end

  def generate_sequence(length) do
    Enum.map(1..length, fn _ -> :rand.uniform() - 1 end)
  end

  def validate_input(user_sequence, correct_sequence) do
    user_sequence == correct_sequence
  end

  def finished?(correct_rounds) do
    correct_rounds >= 7
  end

  def time_limit_ms, do: 2 * 60 * 1000

  def create_result_entry(user_id, task_id, correct_rounds, errors, total_reaction_time, omitted \\ 0) do
    total_attempts = correct_rounds + errors + omitted
    avg_time = if correct_rounds + errors > 0, do: total_reaction_time / (correct_rounds + errors), else: 0

    %{
      user_id: user_id,
      task_id: task_id,
      correct: correct_rounds,
      wrong: errors,
      omitted: omitted,
      accuracy: Float.round(correct_rounds / max(1, total_attempts), 2),
      reaction_time: avg_time
    }
  end
end

defmodule Beam.Exercices.MathOperation do
  @moduledoc """
  Logic for the Math Operation task.
  """

  def generate_question do
    a = :rand.uniform(9)
    b = :rand.uniform(9)
    correct_answer = a + b
    options = generate_options(correct_answer)
    {a, b, correct_answer, options}
  end

  defp generate_options(correct_answer) do
    wrong_answers = Enum.uniq(for _ <- 1..2, do: :rand.uniform(18))
    Enum.shuffle([correct_answer | wrong_answers])
  end

  def validate_answer(user_answer, correct_answer) do
    user_answer == correct_answer
  end

  def calculate_accuracy(correct, wrong, omitted) do
    total = correct + wrong + omitted

    if total > 0 do
      Float.round(correct / total * 100, 2)
    else
      0.0
    end
  end

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

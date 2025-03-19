defmodule Beam.Exercices.MathOperation do
  @moduledoc """
  Lógica para a tarefa de operações matemáticas, com suporte a diferentes dificuldades.
  """

  def generate_question(:facil) do
    a = :rand.uniform(9)
    b = :rand.uniform(9)
    correct_answer = a + b
    options = generate_options(correct_answer, :facil)
    {a, b, "+", correct_answer, options}
  end

  def generate_question(:medio) do
    a = :rand.uniform(75)
    b = :rand.uniform(75)
    operation = Enum.random([:soma, :subtracao])

    {a, b, operator, correct_answer} =
      case operation do
        :soma -> {a, b, "+", a + b}
        :subtracao -> {max(a, b), min(a, b), "-", abs(a - b)}
      end

    options = generate_options(correct_answer, :medio)
    {a, b, operator, correct_answer, options}
  end

  def generate_question(:dificil) do
    a = :rand.uniform(150)
    b = :rand.uniform(150)
    operation = Enum.random([:soma, :subtracao])

    {a, b, operator, correct_answer} =
      case operation do
        :soma -> {a, b, "+", a + b}
        :subtracao -> {max(a, b), min(a, b), "-", abs(a - b)}
      end

    options = generate_options(correct_answer, :dificil)
    {a, b, operator, correct_answer, options}
  end

  def generate_question(:teste), do: generate_question(:medio)
  def generate_question(:criado), do: generate_question(:medio)
  def generate_question(_), do: generate_question(:medio)

  defp generate_options(correct_answer, difficulty) do
    range =
      case difficulty do
        :facil -> 15
        _ -> 10
      end

    min_value = max(0, correct_answer - range)
    max_value = correct_answer + range

    wrong_answers =
      Enum.reduce_while(1..3, [], fn _, acc ->
        candidate = :rand.uniform(max_value - min_value + 1) + min_value
        if candidate != correct_answer and candidate not in acc do
          {:cont, [candidate | acc]}
        else
          {:cont, acc}
        end
      end)

    Enum.shuffle([correct_answer | wrong_answers])
  end

  def validate_answer(user_answer, correct_answer), do: user_answer == correct_answer

  def calculate_accuracy(correct, wrong, omitted) do
    total = correct + wrong + omitted
    if total > 0, do: Float.round(correct / total, 4), else: 0.0
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

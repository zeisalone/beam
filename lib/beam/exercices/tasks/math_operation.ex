defmodule Beam.Exercices.Tasks.MathOperation do
  @behaviour Beam.Exercices.Configurable
  @moduledoc """
  Lógica para a tarefa de operações matemáticas, com suporte a diferentes dificuldades.
  """

  alias Beam.Accounts.Patient
  alias Beam.Repo

  @impl true
  def default_config do
    %{
      equation_display_time: 2000,
      answer_time_limit: 4000,
      max_value: 100,
      operations: "Ambas"
    }
  end

  @impl true
  def config_spec do
    [
      {:equation_display_time, :integer, label: "Tempo de Exibição da Equação (ms)"},
      {:answer_time_limit, :integer, label: "Tempo para Responder (ms)"},
      {:max_value, :integer, label: "Valor Máximo nas Operações"},
      {:operations, :select, label: "Tipo de Operações", options: ["Somar", "Ambas"]}
    ]
  end

  @impl true
  def validate_config(%{
        equation_display_time: eq_time,
        answer_time_limit: ans_time,
        max_value: max,
        operations: ops
      })
      when is_integer(eq_time) and eq_time > 0 and
           is_integer(ans_time) and ans_time > 0 and
           is_integer(max) and max > 0 and
           ops in ["Somar", "Ambas"] do
    :ok
  end

  def validate_config(_), do: {:error, %{message: "Parâmetros inválidos"}}

  def generate_question(:criado, config), do: generate_question_from_config(config)
  def generate_question(:facil, _config) do
    a = :rand.uniform(9)
    b = :rand.uniform(9)
    correct_answer = a + b
    options = generate_options(correct_answer, :facil)
    {a, b, "+", correct_answer, options}
  end

  def generate_question(:medio, _config), do: generate_question_default_range(75)
  def generate_question(:dificil, _config), do: generate_question_default_range(150)
  def generate_question(:criado), do: generate_question(:criado, default_config())
  def generate_question(:facil), do: generate_question(:facil, nil)
  def generate_question(:medio), do: generate_question(:medio, nil)
  def generate_question(:dificil), do: generate_question(:dificil, nil)

  def generate_question(user = %Beam.Accounts.User{}) do
    case get_patient_age(user.id) do
      {:ok, age} ->
        IO.inspect({:idade_do_paciente, age})
        generate_question_by_age(age)
      _ ->
        generate_question(:medio, nil)
    end
  end

  def generate_question(_), do: generate_question(:medio, nil)

  defp get_patient_age(user_id) do
    case Repo.get_by(Patient, user_id: user_id) do
      %Patient{birth_date: birth_date} when not is_nil(birth_date) ->
        today = Date.utc_today()
        years = Date.diff(today, birth_date) |> div(365)
        {:ok, max(years, 0)}
      _ -> :error
    end
  end

  defp generate_question_by_age(age) when is_integer(age) and age >= 0 and age <= 6 do
    a = :rand.uniform(5)
    b = :rand.uniform(5)
    correct_answer = a + b
    options = generate_options(correct_answer, :facil)
    {a, b, "+", correct_answer, options}
  end

  defp generate_question_by_age(age) when is_integer(age) and age >= 7 and age <= 10 do
    a = :rand.uniform(9)
    b = :rand.uniform(9)
    correct_answer = a + b
    options = generate_options(correct_answer, :facil)
    {a, b, "+", correct_answer, options}
  end

  defp generate_question_by_age(age) when is_integer(age) and age >= 11 do
    generate_question(:medio, nil)
  end

  defp generate_question_default_range(max) do
    a = :rand.uniform(max)
    b = :rand.uniform(max)
    operation = Enum.random([:soma, :subtracao])

    {a, b, operator, correct_answer} =
      case operation do
        :soma -> {a, b, "+", a + b}
        :subtracao -> {max(a, b), min(a, b), "-", abs(a - b)}
      end

    options = generate_options(correct_answer, :medio)
    {a, b, operator, correct_answer, options}
  end

  defp generate_question_from_config(%{
         max_value: max,
         operations: ops
       }) do
    a = Enum.random(1..max)
    b = Enum.random(1..max)

    operation =
      case ops do
        "Somar" -> :soma
        "Ambas" -> Enum.random([:soma, :subtracao])
      end

    {a, b, operator, correct_answer} =
      case operation do
        :soma -> {a, b, "+", a + b}
        :subtracao -> {max(a, b), min(a, b), "-", abs(a - b)}
      end

    options = generate_options(correct_answer, :medio)
    {a, b, operator, correct_answer, options}
  end

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

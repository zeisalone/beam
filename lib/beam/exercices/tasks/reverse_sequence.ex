defmodule Beam.Exercices.Tasks.ReverseSequence do
  @behaviour Beam.Exercices.Configurable

  @moduledoc """
  Tarefa que exibe uma sequência de números e o usuário deve digitá-los na ordem inversa.
  """
  def default_config do
    %{
      sequence_duration: 7500,
      response_timeout: 10_000,
      total_attempts: 5,
      sequence_length: 5
    }
  end

  def config_spec do
    [
      {:sequence_duration, :integer, label: "Tempo de Exibição da Sequência (ms)"},
      {:response_timeout, :integer, label: "Tempo para Responder (ms)"},
      {:total_attempts, :integer, label: "Número Total de Tentativas"},
      {:sequence_length, :integer, label: "Tamanho da Sequência"}
    ]
  end

  def validate_config(%{
        sequence_duration: sd,
        response_timeout: rt,
        total_attempts: ta,
        sequence_length: sl
      })
      when is_integer(sd) and sd > 0 and
          is_integer(rt) and rt > 0 and
          is_integer(ta) and ta > 0 and
          is_integer(sl) and sl > 0 do
    :ok
  end

  @doc """
  Gera uma sequência de números baseada na dificuldade.
  """
  def generate_sequence(:facil), do: Enum.map(1..3, fn _ -> Enum.random(0..9) end)
  def generate_sequence(:medio), do: Enum.map(1..5, fn _ -> Enum.random(0..9) end)
  def generate_sequence(:dificil), do: Enum.map(1..7, fn _ -> Enum.random(0..9) end)

  def generate_sequence(:criado, opts) when is_map(opts) do
    len = Map.get(opts, :sequence_length, 5)
    Enum.map(1..len, fn _ -> Enum.random(0..9) end)
  end
  def generate_sequence(_, _), do: generate_sequence(:medio)
  @doc """
  Verifica se a resposta do usuário está correta. Retorna `:correct` ou `:wrong`.
  """
  def validate_response(user_response, original_sequence) do
    if user_response == Enum.reverse(original_sequence), do: :correct, else: :wrong
  end

  @doc """
  Calcula a precisão da tarefa.
  """
  def calculate_accuracy(correct, wrong, omitted) do
    total = correct + wrong + omitted
    if total > 0, do: Float.round(correct / total, 4), else: 0.0
  end

  @doc """
  Compara a resposta do usuário com a sequência correta (invertida).
  Retorna uma tupla com contagem de corretos, errados e omitidos.
  """
  def evaluate_individual_responses(user_input, original_sequence) do
    expected = Enum.reverse(original_sequence)

    Enum.zip(expected, user_input)
    |> Enum.reduce({0, 0, 0}, fn
      {_expected_digit, nil}, {c, w, o} -> {c, w, o + 1}
      {_expected_digit, ""}, {c, w, o} -> {c, w, o + 1}
      {expected_digit, user_digit}, {c, w, o} when user_digit == expected_digit -> {c + 1, w, o}
      {_expected, _user}, {c, w, o} -> {c, w + 1, o}
    end)
  end

  @doc """
  Cria um registro de resultado para a tarefa.
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

defmodule Beam.Exercices.Tasks.OrderAnimals do
  @behaviour Beam.Exercices.Configurable
  @moduledoc """
  Lógica para o exercício Ordenar os Animais.

  Neste exercício, uma sequência de animais é apresentada ao utilizador.
  Depois, o utilizador deve arrastá-los para os espaços correspondentes à ordem em que apareceram.
  """

  @animals ["cat", "dog", "elephant", "ladybug", "ostrich", "pig", "rabbit", "rat"]

  @impl true
  def default_config do
    %{
      total_rounds: 5,
      animal_total_time: 2000,
      min_sequence: 3,
      max_sequence: 6
    }
  end

  @impl true
  def config_spec do
    [
      {:total_rounds, :integer, label: "Número de Rondas"},
      {:animal_total_time, :integer, label: "Tempo de cada animal (ms)"},
      {:min_sequence, :integer, label: "Número mínimo de animais"},
      {:max_sequence, :integer, label: "Número máximo de animais"}
    ]
  end

  @impl true
  def validate_config(cfg) do
    with true <- is_integer(cfg.total_rounds) and cfg.total_rounds > 0,
        true <- is_integer(cfg.animal_total_time) and cfg.animal_total_time > 100,
        true <- is_integer(cfg.min_sequence) and cfg.min_sequence >= 2,
        true <- is_integer(cfg.max_sequence) and cfg.max_sequence >= cfg.min_sequence do
      :ok
    else
      _ -> {:error, %{message: "Parâmetros inválidos"}}
    end
  end


  @doc """
  Gera uma sequência de animais (alvo) conforme a dificuldade.
  """
  def generate_target_sequence(level_or_config) do
    count_range =
      case level_or_config do
        :facil -> 2..4
        :medio -> 4..6
        :dificil -> 5..8
        config when is_map(config) ->
          config.min_sequence..config.max_sequence
      end

    total = Enum.random(count_range)
    Enum.shuffle(@animals) |> Enum.take(total)
end

  @doc """
  Gera a fase do exercício, contendo os animais em ordem aleatória para o utilizador ordenar.
  """
  def generate_phase(target_sequence) do
    %{
      target_sequence: target_sequence,
      shuffled_options: Enum.shuffle(target_sequence)
    }
  end

  @doc """
  Valida a resposta do utilizador, comparando com a sequência correta.
  Retorna `:correct` ou `:wrong`.
  """
  def validate_response(user_sequence, target_sequence) do
    if user_sequence == target_sequence, do: :correct, else: :wrong
  end

  @doc """
  Avalia resposta do utilizador elemento a elemento.
  Retorna tupla `{corretas, erradas, omitidas}`.
  """

  def evaluate_response(user_sequence, target_sequence) do
    zip_longest(target_sequence, user_sequence, nil)
    |> Enum.reduce({0, 0, 0}, fn
      {expected, user}, {c, w, o} when expected == user -> {c + 1, w, o}
      {_, nil}, {c, w, o} -> {c, w, o + 1}
      {_, _}, {c, w, o} -> {c, w + 1, o}
    end)
  end

  defp zip_longest([], [], _pad), do: []
  defp zip_longest([h1 | t1], [], pad), do: [{h1, pad} | zip_longest(t1, [], pad)]
  defp zip_longest([], [h2 | t2], pad), do: [{pad, h2} | zip_longest([], t2, pad)]
  defp zip_longest([h1 | t1], [h2 | t2], pad), do: [{h1, h2} | zip_longest(t1, t2, pad)]

  @doc """
  Calcula a precisão da tarefa.
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
  Cria um registo de resultado da tarefa.
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

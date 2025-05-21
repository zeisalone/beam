defmodule Beam.Exercices.Tasks.NameAndColor do
  @behaviour Beam.Exercices.Configurable
  @moduledoc """
  Lógica para a tarefa "Nome e Cor".
  """

  @words ["Vermelho", "Verde", "Azul", "Amarelo"]
  @colors ["red", "green", "blue", "yellow"]

  def default_config do
    %{
      total_trials: 20,
      display_time: 2000,
      question_time: 5000,
      question_type: "Ambas"
    }
  end

  def config_spec do
    [
      {:total_trials, :integer, label: "Número de Tentativas"},
      {:display_time, :string, label: "Tempo de Exibição da Palavra (ms)"},
      {:question_time, :string, label: "Tempo da Pergunta (ms)"},
      {:question_type, :select, label: "Tipo de Pergunta", options: ["Pela Palavra", "Pela Cor", "Ambas"]}
    ]
  end

  def validate_config(%{
        total_trials: t,
        display_time: dt,
        question_time: qtime,
        question_type: qt
      })
      when is_integer(t) and t > 0 and
           is_integer(dt) and dt > 0 and
           is_integer(qtime) and qtime > 0 and
           qt in ["Pela Palavra", "Pela Cor", "Ambas"] do
    :ok
  end

  def validate_config(_),
    do: {:error, %{message: "Parâmetros inválidos. Verifique os tempos e o tipo de pergunta."}}

  @doc """
  Gera uma lista de fases com palavras e cores trocadas.
  """
  def generate_trials(num_trials) do
    Enum.map(1..num_trials, fn _ ->
      word = Enum.random(@words)
      color = Enum.random(@colors -- [color_from_word(word)])
      %{word: word, color: color, correct_answer: Enum.random([:word, :color])}
    end)
  end

  defp color_from_word("Vermelho"), do: "red"
  defp color_from_word("Verde"), do: "green"
  defp color_from_word("Azul"), do: "blue"
  defp color_from_word("Amarelo"), do: "yellow"

  @doc """
  Valida a resposta do utilizador comparando com o valor correto (palavra ou cor).
  """
  def validate_response(response, trial) do
    expected =
      case trial.correct_answer do
        :word -> trial.word
        :color -> color_label(trial.color)
      end

    if response == expected, do: :correct, else: :wrong
  end

  defp color_label("red"), do: "Vermelho"
  defp color_label("green"), do: "Verde"
  defp color_label("blue"), do: "Azul"
  defp color_label("yellow"), do: "Amarelo"

  @doc """
  Dada uma trial e o tipo de pergunta (:word ou :color), devolve a resposta correta como string.
  """
  def correct_answer(%{word: word, color: _color}, :word), do: word
  def correct_answer(%{word: _word, color: color}, :color), do: color_label(color)

  @doc """
  Gera uma lista de 4 opções para a pergunta, incluindo a resposta correta e as erradas.
  """
  def generate_options(%{word: word, color: color}, :word) do
    correct = word
    opposite = color_label(color)

    extras =
      (@words -- [correct, opposite])
      |> Enum.shuffle()
      |> Enum.take(2)

    Enum.shuffle([correct, opposite | extras])
  end

  def generate_options(%{word: word, color: color}, :color) do
    correct = color_label(color)
    opposite = word

    extras =
      (color_labels() -- [correct, opposite])
      |> Enum.shuffle()
      |> Enum.take(2)

    Enum.shuffle([correct, opposite | extras])
  end

  defp color_labels(), do: ["Vermelho", "Verde", "Azul", "Amarelo"]

  @doc """
  Calcula a precisão.
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
  Cria o entry final para guardar no banco.
  """
  def create_result_entry(user_id, task_id, correct, wrong, omitted, avg_reaction_time) do
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

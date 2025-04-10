defmodule Beam.Exercices.Tasks.CodeOfSymbols do
  @moduledoc """
  Tarefa que apresenta um código de símbolos (figuras com cores), onde cada símbolo representa um número específico.
  O utilizador deverá preencher uma grelha com os números corretos associados a cada símbolo.
  """

  @shapes ["circle", "square", "triangle", "star", "heart"]
  @colors ["red", "blue", "green", "yellow", "purple", "orange", "teal", "pink"]

  @doc """
  Gera o código de símbolo -> número aleatoriamente consoante a dificuldade.
  """
  def generate_code(:facil), do: generate_code_for(4)
  def generate_code(:medio), do: generate_code_for(6)
  def generate_code(:dificil), do: generate_code_for(8)
  def generate_code(_), do: generate_code(:medio)

  defp generate_code_for(count) do
    Enum.zip(
      Enum.take_random(all_symbols(), count),
      Enum.to_list(0..(count - 1))
    )
    |> Enum.map(fn {{shape, color}, digit} -> %{shape: shape, color: color, digit: digit} end)
  end

  defp all_symbols do
    for shape <- @shapes, color <- @colors, do: {shape, color}
  end

  @doc """
  Gera a grelha com símbolos aleatórios a partir do código gerado.
  """
  def generate_grid(code, :facil), do: generate_grid_for(code, 4 * 4)
  def generate_grid(code, :medio), do: generate_grid_for(code, 5 * 5)
  def generate_grid(code, :dificil), do: generate_grid_for(code, 6 * 6)
  def generate_grid(code, _), do: generate_grid(code, :medio)

  defp generate_grid_for(code, total_cells) do
    Enum.map(1..total_cells, fn _ -> Enum.random(code) end)
  end

  @doc """
  Avalia cada resposta inserida em relação à grelha original.
  """
  def evaluate_responses(grid, user_input) do
    Enum.zip(grid, user_input)
    |> Enum.reduce({0, 0, 0}, fn
      {%{digit: _expected}, nil}, {c, w, o} -> {c, w, o + 1}
      {%{digit: _expected}, ""}, {c, w, o} -> {c, w, o + 1}
      {%{digit: expected}, actual}, {c, w, o} when actual == expected -> {c + 1, w, o}
      {_symbol, _actual}, {c, w, o} -> {c, w + 1, o}
    end)
  end

  @doc """
  Calcula a precisão.
  """
  def calculate_accuracy(correct, wrong, omitted) do
    total = correct + wrong + omitted
    if total > 0, do: Float.round(correct / total, 4), else: 0.0
  end

  @doc """
  Cria a entrada de resultado.
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

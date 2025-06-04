defmodule Beam.Exercices.Tasks.CodeOfSymbols do
  @behaviour Beam.Exercices.Configurable
  alias Beam.Accounts.Patient
  alias Beam.Repo
  @moduledoc """
  Tarefa que apresenta um código de símbolos (figuras com cores), onde cada símbolo representa um número específico.
  O utilizador deverá preencher uma grelha com os números corretos associados a cada símbolo.
  """

  @shapes ["circle", "square", "triangle", "star", "heart"]
  @colors ["red", "blue", "green", "yellow", "purple", "orange", "teal", "pink"]

  @impl true
  def default_config do
    %{
      response_timeout: 45_000,
      symbol_count: 6,
      grid_cell_count: 25
    }
  end

  @impl true
  def config_spec do
    [
      {:response_timeout, :integer, label: "Tempo de Resposta (ms)"},
      {:symbol_count, :integer, label: "Número de Símbolos"},
      {:grid_cell_count, :integer, label: "Tamanho da Grelha (número de células)"}
    ]
  end

  @impl true
  def validate_config(%{response_timeout: t, symbol_count: sc, grid_cell_count: gc})
      when is_integer(t) and t > 0 and is_integer(sc) and sc > 0 and is_integer(gc) and gc > 0 do
    :ok
  end

  def validate_config(_), do: {:error, %{message: "Parâmetros inválidos"}}

  def get_patient_age(user_id) do
    case Repo.get_by(Patient, user_id: user_id) do
      %Patient{birth_date: birth_date} when not is_nil(birth_date) ->
        today = Date.utc_today()
        years = Date.diff(today, birth_date) |> div(365)
        {:ok, max(years, 0)}
      _ -> :error
    end
  end

  def choose_level_by_age(user_id) do
    case get_patient_age(user_id) do
      {:ok, age} when is_integer(age) and age <= 10 -> :facil
      {:ok, age} when is_integer(age) and age >= 11 -> :medio
      _ -> :medio
    end
  end

  @doc """
  Gera o código de símbolo -> número aleatoriamente consoante a dificuldade ou configuração.
  """
  def generate_code(difficulty, config \\ %{})

  def generate_code(:facil, _), do: generate_code_for(4)
  def generate_code(:medio, _), do: generate_code_for(6)
  def generate_code(:dificil, _), do: generate_code_for(8)
  def generate_code(:criado, config) when is_map(config), do: generate_code_for(Map.get(config, :symbol_count, 6))
  def generate_code(_, _), do: generate_code_for(6)

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
  def generate_grid(code, difficulty, config \\ %{})

  def generate_grid(code, :facil, _), do: generate_grid_for(code, 4 * 4)
  def generate_grid(code, :medio, _), do: generate_grid_for(code, 5 * 5)
  def generate_grid(code, :dificil, _), do: generate_grid_for(code, 6 * 6)
  def generate_grid(code, :criado, config) when is_map(config), do: generate_grid_for(code, Map.get(config, :grid_cell_count, 25))
  def generate_grid(code, _, _), do: generate_grid_for(code, 5 * 5)

  defp generate_grid_for(code, total_cells) do
    Enum.map(1..total_cells, fn _ -> Enum.random(code) end)
  end

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

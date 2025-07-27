defmodule Beam.Exercices.Tasks.OddOneOut do
  @behaviour Beam.Exercices.Configurable

  @moduledoc """
  Exercício 'O diferente': o utilizador deve encontrar o elemento diferente numa grelha de caracteres.
  A grelha é sempre quadrada e o tamanho varia consoante o desempenho e a dificuldade/configuração.
  """

  @default_combinations [
    {"n", "m"},
    {"E", "F"},
    {"d", "b"},
    {"1", "I"},
    {"2", "3"},
    {"62", "26"},
    {"0", "o"}
  ]

  @min_grid 3
  @max_grid 9

  @impl true
  def default_config do
    %{
      total_rounds: 20,
      min_grid_size: 3,
      max_grid_size: 9,
      combinations_count: 1
    }
  end

  @impl true
  def config_spec do
    [
      {:total_rounds, :integer, label: "Número de rondas"},
      {:min_grid_size, :integer, label: "Tamanho mínimo da grelha (3 a 9)"},
      {:max_grid_size, :integer, label: "Tamanho máximo da grelha (3 a 9)"},
      {:combinations_count, :integer, label: "Nº de combinações distintas (1 a 7)"}
    ]
  end

  @impl true
  def validate_config(%{
        total_rounds: tr,
        min_grid_size: min_g,
        max_grid_size: max_g,
        combinations_count: cc
      })
      when is_integer(tr) and tr > 0 and
           is_integer(min_g) and min_g >= @min_grid and
           is_integer(max_g) and max_g <= @max_grid and
           min_g <= max_g and
           is_integer(cc) and cc >= 1 and cc <= length(@default_combinations) do
    :ok
  end

  def validate_config(_), do: {:error, %{message: "Parâmetros inválidos"}}

  def setup(difficulty, config \\ %{})
  def setup(:facil, _config) do
    %{
      grid_size: 4,
      min_grid_size: 3,
      max_grid_size: 5,
      combinations: [Enum.random(@default_combinations)],
      total_rounds: 20
    }
  end

  def setup(:medio, _config) do
    combs = Enum.take_random(@default_combinations, 3)
    %{
      grid_size: 5,
      min_grid_size: 3,
      max_grid_size: 6,
      combinations: combs,
      total_rounds: 20
    }
  end

  def setup(:dificil, _config) do
    %{
      grid_size: 6,
      min_grid_size: 4,
      max_grid_size: 9,
      combinations: @default_combinations,
      total_rounds: 20
    }
  end

  def setup(:criado, config) do
    min_grid = Map.get(config, :min_grid_size, 3) |> clamp(@min_grid, @max_grid)
    max_grid = Map.get(config, :max_grid_size, 9) |> clamp(@min_grid, @max_grid)
    cc = Map.get(config, :combinations_count, 1)
    total_rounds = Map.get(config, :total_rounds, 20)
    grid_size = max(min_grid, min(max_grid, 4))

    combs = Enum.take_random(@default_combinations, cc)

    %{
      grid_size: grid_size,
      min_grid_size: min_grid,
      max_grid_size: max_grid,
      combinations: combs,
      total_rounds: total_rounds
    }
  end

  def clamp(val, min, max), do: max(min, min(val, max))

  def initial_state(difficulty, config \\ %{}) do
    setup = setup(difficulty, config)
    %{
      grid_size: setup.grid_size,
      min_grid_size: setup.min_grid_size,
      max_grid_size: setup.max_grid_size,
      combinations: setup.combinations,
      current_combo: 0,
      correct_streak: 0,
      error_streak: 0,
      total_rounds: setup.total_rounds,
      round: 1,
      results: []
    }
  end

  def generate_grid(state) do
    grid_size = state.grid_size

    combo = Enum.random(state.combinations)
    {a, b} = combo |> Tuple.to_list() |> Enum.shuffle() |> List.to_tuple()
    main = a
    odd = b

    total_cells = grid_size * grid_size
    odd_pos = Enum.random(0..(total_cells - 1))

    grid =
      for i <- 0..(total_cells - 1) do
        if i == odd_pos do
          odd
        else
          main
        end
      end

    %{grid: grid, odd_index: odd_pos, main: main, odd: odd}
  end

  def next_round(state, last_correct?) do
    streak_up = if last_correct?, do: state.correct_streak + 1, else: 0
    streak_down = if not last_correct?, do: state.error_streak + 1, else: 0

    grid_size =
      cond do
        last_correct? and streak_up >=  3 ->
          min(state.grid_size + 1, state.max_grid_size)
        not last_correct? and streak_down >= 3 ->
          max(state.grid_size - 1, state.min_grid_size)
        true ->
          state.grid_size
      end

    current_combo =
      case length(state.combinations) do
        1 -> 0
        n when n > 1 -> rem(state.current_combo + 1, n)
        _ -> 0
      end

    %{
      state
      | round: state.round + 1,
        grid_size: grid_size,
        current_combo: current_combo,
        correct_streak: if(last_correct?, do: streak_up, else: 0),
        error_streak: if(last_correct?, do: 0, else: streak_down)
    }
  end

  def evaluate_answer(state, grid, picked_index) do
    odd_index = Enum.find_index(grid, &(&1 == state.grid |> Enum.at(state.odd_index)))
    correct = picked_index == odd_index
    correct
  end

  def calculate_accuracy(correct, wrong, omitted) do
    total = correct + wrong + omitted
    if total > 0 do
      Float.round(correct / total, 4)
    else
      0.0
    end
  end
end

defmodule Beam.Exercices.Tasks.Simon do
  @behaviour Beam.Exercices.Configurable

  @moduledoc """
  Lógica para o exercício do tipo Simon.
  """

  @colors ["red", "blue", "green", "yellow", "purple", "orange", "teal", "pink", "brown"]

  @impl true
  def default_config do
    %{
      grid_size: 6,
      sequence_length: 7,
      time_limit_ms: 2 * 60 * 1000
    }
  end

  @impl true
  def config_spec do
    [
      {:grid_size, :integer, label: "Tamanho da grelha (4, 6, 9)"},
      {:sequence_length, :integer, label: "Número de passos da sequência"},
      {:time_limit_ms, :integer, label: "Tempo limite total (ms)"}
    ]
  end

  @impl true
  def validate_config(cfg) do
    with true <- cfg.grid_size in [4, 6, 9],
         true <- is_integer(cfg.sequence_length) and cfg.sequence_length > 0,
         true <- is_integer(cfg.time_limit_ms) and cfg.time_limit_ms > 10000 do
      :ok
    else
      _ -> {:error, %{message: "Parâmetros inválidos para o Simon"}}
    end
  end

  def generate_colors(difficulty_or_config) do
    count =
      case difficulty_or_config do
        :facil -> 4
        :medio -> 6
        :dificil -> 9
        %{grid_size: size} -> size
        _ -> 6
      end

    Enum.take_random(@colors, count)
  end

  def generate_sequence(length_or_config) do
    length =
      case length_or_config do
        %{sequence_length: n} -> n
        _ -> 7
      end

    Enum.map(1..length, fn _ -> :rand.uniform() - 1 end)
  end

  def validate_input(user_sequence, correct_sequence) do
    user_sequence == correct_sequence
  end

  def finished?(correct_rounds, difficulty_or_config) do
    target =
      case difficulty_or_config do
        %{sequence_length: n} -> n
        _ -> 7
      end

    correct_rounds >= target
  end

  def time_limit_ms(difficulty_or_config \\ nil) do
    case difficulty_or_config do
      %{time_limit_ms: ms} -> ms
      _ -> 2 * 60 * 1000
    end
  end

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

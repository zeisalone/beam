defmodule Beam.Exercices.Tasks.FollowTheFigure do
  @behaviour Beam.Exercices.Configurable

  @moduledoc """
  Lógica para o exercício "Segue a Forma".
  """

  @shapes ["circle", "square", "triangle", "star", "heart"]
  @colors ["red", "blue", "green", "yellow", "purple", "orange"]

  @impl true
  def default_config do
    %{
      total_rounds: 20,
      initial_time: 15_000,
      gain_time: 4_000,
      penalty_time: 2_000,
      movement: "Lentamente",
      overlap: "Pouca",
      color_similarity: "Alguma Parecença",
      min_figures: 30,
      max_figures: 70
    }
  end

  @impl true
  def config_spec do
    [
      {:total_rounds, :integer, label: "Número Total de Rondas"},
      {:initial_time, :integer, label: "Tempo Inicial (ms)"},
      {:gain_time, :integer, label: "Tempo Ganho por Acerto (ms)"},
      {:penalty_time, :integer, label: "Penalização por Erro (ms)"},
      {:movement, :select, label: "As figuras devem mover-se?", options: ["Não", "Lentamente", "Velocidade moderada", "Rapidamente"]},
      {:overlap, :select, label: "Quanta sobreposição de figuras deve haver?", options: ["Pouca", "Moderada", "Muita"]},
      {:color_similarity, :select, label: "Quão parecida deve ser a cor do alvo?", options: ["Completamente Aleatório", "Alguma Parecença", "Muita Parecença"]},
      {:min_figures, :integer, label: "Número mínimo de figuras"},
      {:max_figures, :integer, label: "Número máximo de figuras"}
    ]
  end

  @impl true
  def validate_config(cfg) do
    with true <- is_integer(cfg.total_rounds) and cfg.total_rounds > 3,
         true <- is_integer(cfg.initial_time) and cfg.initial_time > 1,
         true <- is_integer(cfg.gain_time) and cfg.gain_time >= 0,
         true <- is_integer(cfg.penalty_time) and cfg.penalty_time >= 0,
         true <- cfg.movement in ["Não", "Lentamente", "Velocidade moderada", "Rapidamente"],
         true <- cfg.overlap in ["Pouca", "Moderada", "Muita"],
         true <- cfg.color_similarity in ["Completamente Aleatório", "Alguma Parecença", "Muita Parecença"],
         true <- is_integer(cfg.min_figures) and cfg.min_figures > 2,
         true <- is_integer(cfg.max_figures) and cfg.max_figures >= cfg.min_figures do
      :ok
    else
      _ -> {:error, %{message: "Parâmetros inválidos"}}
    end
  end

  def generate_round(round_index, level_or_config) do
    target = %{
      shape: Enum.random(@shapes),
      color: Enum.random(@colors)
    }

    if round_index <= 2 do
      distractors =
        1..8
        |> Enum.map(fn _ ->
          Map.put(generate_distractor(target, Enum.random(@colors -- [target.color])), :layout, :center_block)
        end)

      target_with_layout = Map.put(target, :layout, :center_block)

      %{
        figures: Enum.shuffle([target_with_layout | distractors]),
        target: target_with_layout,
        moving: false,
        overlap: false
      }
    else
      case level_or_config do
        level when level in [:facil, :medio, :dificil] ->
          distractors = generate_distractors_from_difficulty(target, round_index, level)

          %{
            figures: Enum.shuffle([target | distractors]),
            target: target,
            moving: should_move_from_difficulty(level),
            overlap: should_overlap_from_difficulty(level, round_index)
          }

        config when is_map(config) ->
          distractors = generate_distractors_from_config(target, round_index, config)

          %{
            figures: Enum.shuffle([target | distractors]),
            target: target,
            moving: should_move_from_config(config.movement),
            overlap: should_overlap_from_config(config.overlap)
          }
      end
    end
  end


  defp generate_distractors_from_difficulty(target, _round, :facil) do
    count = Enum.random(8..12)

    colors =
      List.duplicate(@colors -- [target.color], ceil(count / 5))
      |> List.flatten()
      |> Enum.take(count)
      |> Enum.shuffle()

    Enum.map(colors, &generate_distractor(target, &1))
  end

  defp generate_distractors_from_difficulty(target, _round, :medio) do
    count = Enum.random(30..70)
    generate_biased_distractors(target, count, 0.35)
  end

  defp generate_distractors_from_difficulty(target, _round, :dificil) do
    count = Enum.random(90..150)
    generate_biased_distractors(target, count, 0.55)
  end

  defp generate_biased_distractors(target, count, same_color_ratio) do
    same_color_count = round(count * same_color_ratio)
    other_color_count = count - same_color_count

    same_colors = List.duplicate(target.color, same_color_count)
    other_colors = Enum.take(Stream.cycle(@colors -- [target.color]), other_color_count)

    color_list = Enum.shuffle(same_colors ++ other_colors)

    Enum.map(1..count, fn i ->
      generate_distractor(target, Enum.at(color_list, rem(i - 1, length(color_list))))
    end)
  end

  defp should_move_from_difficulty(:facil), do: false
  defp should_move_from_difficulty(:medio), do: :rand.uniform() < 0.4
  defp should_move_from_difficulty(:dificil), do: :rand.uniform() < 0.75

  defp should_overlap_from_difficulty(_level, round) when round <= 2, do: false
  defp should_overlap_from_difficulty(:facil, _), do: :rand.uniform() < 0.15
  defp should_overlap_from_difficulty(:medio, _), do: :rand.uniform() < 0.4
  defp should_overlap_from_difficulty(:dificil, _), do: :rand.uniform() < 0.75


  defp generate_distractors_from_config(target, _round, config) do
    count = Enum.random(config.min_figures..config.max_figures)

    color_bias =
      case config.color_similarity do
        "Completamente Aleatório" ->
          Enum.shuffle(Enum.take(Stream.cycle(@colors -- [target.color]), count))

        "Alguma Parecença" ->
          build_color_bias(target.color, count, 0.35)

        "Muita Parecença" ->
          build_color_bias(target.color, count, 0.55)
      end

    Enum.map(1..count, fn i ->
      generate_distractor(target, Enum.at(color_bias, rem(i - 1, length(color_bias))))
    end)
  end

  defp build_color_bias(target_color, count, ratio) do
    same_color_count = round(count * ratio)
    other_color_count = count - same_color_count

    same_colors = List.duplicate(target_color, same_color_count)
    other_colors = Enum.take(Stream.cycle(@colors -- [target_color]), other_color_count)

    Enum.shuffle(same_colors ++ other_colors)
  end

  defp should_move_from_config("Não"), do: false
  defp should_move_from_config("Lentamente"), do: :rand.uniform() < 0.25
  defp should_move_from_config("Velocidade moderada"), do: :rand.uniform() < 0.5
  defp should_move_from_config("Rapidamente"), do: :rand.uniform() < 0.85

  defp should_overlap_from_config("Pouca"), do: :rand.uniform() < 0.15
  defp should_overlap_from_config("Moderada"), do: :rand.uniform() < 0.4
  defp should_overlap_from_config("Muita"), do: :rand.uniform() < 0.75


  defp generate_distractor(%{shape: s, color: c}, distractor_color) do
    distractor_color = distractor_color || Enum.random(@colors -- [c])
    shape = Enum.random(@shapes -- [s])

    if shape == s and distractor_color == c do
      generate_distractor(%{shape: s, color: c}, distractor_color)
    else
      %{shape: shape, color: distractor_color}
    end
  end

  def validate_selection(%{shape: s, color: c}, %{shape: s, color: c}), do: :correct
  def validate_selection(_, _), do: :wrong

  def calculate_accuracy(correct, wrong, omitted) do
    total = correct + wrong + omitted
    if total > 0, do: Float.round(correct / total * 100, 2), else: 0.0
  end

  def create_result_entry(user_id, task_id, correct, wrong, omitted, total_time) do
    total = correct + wrong + omitted
    avg_time = if total > 0, do: total_time / total, else: 0

    %{
      user_id: user_id,
      task_id: task_id,
      correct: correct,
      wrong: wrong,
      omitted: omitted,
      accuracy: calculate_accuracy(correct, wrong, omitted),
      reaction_time: avg_time
    }
  end
end

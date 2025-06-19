defmodule BeamWeb.ExerciseConfig.Labels do
  @moduledoc """
  Tradução dos nomes internos das variáveis de configuração para nomes amigáveis em português.
  """

  @labels %{
    answer_time_limit: "Tempo para Responder",
    equation_display_time: "Tempo de Exibição da Equação",
    max_value: "Valor Máximo",
    operations: "Tipo de Operações",
    cycle_duration: "Duração do Ciclo",
    phase_duration: "Duração da Fase",
    total_phases: "Número Total de Fases",
    display_time: "Tempo de Exibição",
    total_trials: "Total de Tentativas",
    response_timeout: "Tempo Limite de Resposta",
    sequence_duration: "Duração da Sequência",
    sequence_length: "Comprimento da Sequência",
    total_attempts: "Total de Tentativas",
    grid_cell_count: "Número de Células na Grelha",
    symbol_count: "Número de Símbolos",
    question_time: "Tempo para Responder à Questão",
    question_type: "Tipo de Questão",
    color_similarity: "Semelhança de Cor",
    gain_time: "Tempo de Bônus",
    initial_time: "Tempo Inicial",
    max_figures: "Número Máximo de Figuras",
    min_figures: "Número Mínimo de Figuras",
    movement: "Movimento",
    overlap: "Sobreposição",
    penalty_time: "Tempo de Penalização",
    total_rounds: "Total de Rondas",
    grid_size: "Tamanho da Grelha",
    time_limit_ms: "Tempo Limite (ms)",
    animal_total_time: "Tempo por Animal",
    max_sequence: "Tamanho Máximo da Sequência",
    min_sequence: "Tamanho Mínimo da Sequência",
    num_distractors_list: "Número de Distratores"
  }

  @doc """
  Devolve o nome amigável em português para uma chave de configuração.
  """
  def label_for(key) when is_atom(key), do: Map.get(@labels, key, key |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize())
  def label_for(key) when is_binary(key), do: key |> String.to_existing_atom() |> label_for()
end

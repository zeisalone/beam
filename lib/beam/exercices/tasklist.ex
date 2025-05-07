defmodule Beam.Exercices.TaskList do
  @moduledoc "Task list with fixed IDs"

  @task_mapping %{
    math_operation: 1,
    searching_for_an_answer: 2,
    less_than_five: 3,
    reverse_sequence: 4,
    code_of_symbols: 5,
    name_and_color: 6,
    follow_the_figure: 7,
    simon: 8,
    searching_for_a_vowel: 9,
  }

  def task_id(:math_operation), do: Map.get(@task_mapping, :math_operation)
  def task_id(:searching_for_an_answer), do: Map.get(@task_mapping, :searching_for_an_answer)
  def task_id(:less_than_five), do: Map.get(@task_mapping, :less_than_five)
  def task_id(:reverse_sequence), do: Map.get(@task_mapping, :reverse_sequence)
  def task_id(:code_of_symbols), do: Map.get(@task_mapping, :code_of_symbols)
  def task_id(:name_and_color), do: Map.get(@task_mapping, :name_and_color)
  def task_id(:follow_the_figure), do: Map.get(@task_mapping, :follow_the_figure)
  def task_id(:simon), do: Map.get(@task_mapping, :simon)
  def task_id(:searching_for_a_vowel), do: Map.get(@task_mapping, :searching_for_a_vowel)
end

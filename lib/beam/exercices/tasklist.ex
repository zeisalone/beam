defmodule Beam.Exercices.TaskList do
  @moduledoc "Task list with fixed IDs"

  @task_mapping %{
    math_operation: 1,
    searching_for_an_answer: 2,
    greater_than_five: 3,
    reverse_sequence: 4
  }

  def task_id(:math_operation), do: Map.get(@task_mapping, :math_operation)
  def task_id(:searching_for_an_answer), do: Map.get(@task_mapping, :searching_for_an_answer)
  def task_id(:greater_than_five), do: Map.get(@task_mapping, :greater_than_five)
  def task_id(:reverse_sequence), do: Map.get(@task_mapping, :reverse_sequence)
end

defmodule Beam.Exercices.Tasks.LessThanFive do
  @behaviour Beam.Exercices.Configurable
  @moduledoc """
  Logic for the Greater Than Five task.
  """

  def default_config do
    %{
      total_trials: 20,
      display_time: 2000
    }
  end

  def config_spec do
    [
      {:total_trials, :integer, label: "Número de Rondas"},
      {:display_time, :integer, label: "Tempo de Exibição (ms)"}
    ]
  end

  def validate_config(%{total_trials: n, display_time: t})
      when is_integer(n) and n > 0 and is_integer(t) and t > 0 do
    :ok
  end

  def validate_config(_), do: {:error, %{message: "Parâmetros inválidos"}}

  # Números permitidos (exclui 5)
  @numbers Enum.to_list(1..9) -- [5]
  # Cores para o nível difícil
  @colors [:black, :red, :green]

  @doc """
  Generate a sequence of numbers for the task.

  Ensures an equal number of numbers <5 and >5 while keeping the sequence random.
  """
  def generate_sequence(num_trials, difficulty) do
    half_trials = div(num_trials, 2)
    extra = rem(num_trials, 2)

    lower_numbers =
      Stream.repeatedly(fn -> Enum.random(Enum.filter(@numbers, &(&1 < 5))) end)
      |> Enum.take(half_trials)

    higher_numbers =
      Stream.repeatedly(fn -> Enum.random(Enum.filter(@numbers, &(&1 > 5))) end)
      |> Enum.take(half_trials)

    extra_list =
      if extra == 0 do
        []
      else
        [Enum.random(@numbers)]
      end

    numbers = Enum.shuffle(lower_numbers ++ higher_numbers ++ extra_list)

    case difficulty do
      :dificil ->
        Enum.map(numbers, fn num -> %{value: num, color: Enum.random(@colors)} end)

      _ ->
        Enum.map(numbers, fn num -> %{value: num, color: :black} end)
    end
  end

  @doc """
  Validate the user's response.
  - :correct -> Pressionou "space" corretamente quando o número era menor que 5 OU NÃO pressionou quando era maior que 5.
  - :wrong -> Pressionou "space" quando o número era maior que 5.
  - :omitted -> Não pressionou "space" quando o número era menor que 5.
  """
  def validate_response(user_pressed, number, reaction_time, max_time) do
    cond do
      (number < 5 and user_pressed and reaction_time <= max_time) or
          (number > 5 and not user_pressed) ->
        :correct

      number > 5 and user_pressed ->
        :wrong

      number < 5 and not user_pressed ->
        :omitted

      true ->
        :wrong
    end
  end

  @doc """
  Calculate accuracy for the task.
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
  Create a result entry for the task.
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

defmodule BeamWeb.Tasks.ReverseSequenceLive do
  use BeamWeb, :live_view
  alias Beam.Exercices.Tasks.ReverseSequence
  alias Beam.Repo
  alias Beam.Exercices.Result

  @default_sequence_duration 7500
  @default_response_timeout 10_000
  @default_total_attempts 5
  @default_sequence_length 5

  def mount(_params, session, socket) do
    current_user = Map.get(session, "current_user", nil)
    task_id = Map.get(session, "task_id", nil)
    live_action = Map.get(session, "live_action", "training") |> maybe_to_atom()
    difficulty_raw = Map.get(session, "difficulty", nil)

    difficulty =
      case difficulty_raw do
        nil -> nil
        "nil" -> nil
        "" -> nil
        _ -> maybe_to_atom(difficulty_raw)
      end

    raw_config = Map.get(session, "config", %{})

    config =
      Map.merge(
        ReverseSequence.default_config(),
        if(is_map(raw_config), do: atomize_keys(raw_config), else: %{})
      )

    sequence_duration = Map.get(config, :sequence_duration, @default_sequence_duration)
    response_timeout = Map.get(config, :response_timeout, @default_response_timeout)
    total_attempts = Map.get(config, :total_attempts, @default_total_attempts)

    if current_user do
      chosen_difficulty =
        if is_nil(difficulty) do
          ReverseSequence.choose_level_by_age(current_user.id)
        else
          difficulty
        end

      if connected?(socket), do: Process.send_after(self(), :start_round, 500)

      {:ok,
      assign(socket,
        current_user: current_user,
        user_id: current_user.id,
        task_id: task_id,
        sequence: [],
        user_input: [],
        correct: 0,
        wrong: 0,
        omitted: 0,
        full_sequence: 0,
        attempts: 0,
        start_time: nil,
        total_reaction_time: 0,
        timeout_ref: nil,
        live_action: live_action,
        difficulty: chosen_difficulty,
        show_sequence: false,
        full_screen?: true,
        game_finished: false,
        preparing: true,
        sequence_duration: sequence_duration,
        response_timeout: response_timeout,
        total_attempts: total_attempts,
        config: config
      )}
    else
      {:ok, push_navigate(socket, to: "/tasks")}
    end
  end


  defp atomize_keys(map) do
    for {k, v} <- map, into: %{} do
      key = if is_binary(k), do: String.to_existing_atom(k), else: k
      {key, v}
    end
  end

  defp maybe_to_atom(nil), do: nil
  defp maybe_to_atom(value) when is_binary(value), do: String.to_existing_atom(value)
  defp maybe_to_atom(value), do: value

  def handle_info(:hide_sequence, socket) do
    timeout_ref = Process.send_after(self(), :timeout, socket.assigns.response_timeout)
    {:noreply, assign(socket, show_sequence: false, start_time: System.monotonic_time(), timeout_ref: timeout_ref)}
  end

  def handle_info(:start_round, socket) do
    sequence =
      case socket.assigns.difficulty do
        :criado ->
          length = Map.get(socket.assigns.config, :sequence_length, @default_sequence_length)
          ReverseSequence.generate_sequence(:criado, %{sequence_length: length})

        diff -> ReverseSequence.generate_sequence(diff)
      end

    Process.send_after(self(), :hide_sequence, socket.assigns.sequence_duration)

    {:noreply,
     assign(socket,
       preparing: false,
       show_sequence: true,
       sequence: sequence,
       user_input: List.duplicate("", length(sequence)),
       timeout_ref: nil
     )}
  end

  def handle_info(:timeout, socket) do
    if socket.assigns.game_finished do
      {:noreply, socket}
    else
      padded_input =
        socket.assigns.user_input ++ List.duplicate(nil, length(socket.assigns.sequence) - length(socket.assigns.user_input))

      {correct, wrong, omitted} =
        ReverseSequence.evaluate_individual_responses(padded_input, socket.assigns.sequence)

      was_full_correct =
        Enum.all?(padded_input, &(!is_nil(&1) and &1 != "")) and
          ReverseSequence.validate_response(padded_input, socket.assigns.sequence) == :correct

      new_full_sequence =
        if was_full_correct, do: socket.assigns.full_sequence + 1, else: socket.assigns.full_sequence

      reaction_time_ms = socket.assigns.response_timeout
      new_attempts = socket.assigns.attempts + 1
      new_total_reaction_time = socket.assigns.total_reaction_time + reaction_time_ms

      new_correct = socket.assigns.correct + correct
      new_wrong = socket.assigns.wrong + wrong
      new_omitted = socket.assigns.omitted + omitted

      if new_attempts >= socket.assigns.total_attempts do
        send(self(), :save_results)

        {:noreply,
         assign(socket,
           correct: new_correct,
           wrong: new_wrong,
           omitted: new_omitted,
           total_reaction_time: new_total_reaction_time,
           full_sequence: new_full_sequence,
           game_finished: true
         )}
      else
        send(self(), :start_round)

        {:noreply,
         assign(socket,
           correct: new_correct,
           wrong: new_wrong,
           omitted: new_omitted,
           full_sequence: new_full_sequence,
           attempts: new_attempts,
           total_reaction_time: new_total_reaction_time
         )}
      end
    end
  end

  def handle_info(:save_results, socket) do
    {task_id, result_id} = save_final_result(socket)

    case socket.assigns.live_action do
      :test ->
        Beam.Exercices.save_test_attempt(socket.assigns.user_id, task_id, result_id)

      :training ->
        Beam.Exercices.save_training_attempt(
          socket.assigns.user_id,
          task_id,
          result_id,
          socket.assigns.difficulty
        )
    end

    Process.sleep(5000)
    {:noreply, push_navigate(socket, to: ~p"/results/aftertask?task_id=#{task_id}")}
  end

  def handle_event("update_input", %{"numbers" => numbers}, socket) do
    user_input =
      numbers
      |> Enum.filter(fn {k, _} -> Regex.match?(~r/^\d+$/, k) end)
      |> Enum.sort_by(fn {k, _} -> String.to_integer(k) end)
      |> Enum.map(fn {_k, v} ->
        case Integer.parse(v) do
          {int, _} -> int
          :error -> nil
        end
      end)

    {:noreply, assign(socket, user_input: user_input)}
  end

  def handle_event("submit", %{"numbers" => numbers}, socket) do
    if socket.assigns.timeout_ref, do: Process.cancel_timer(socket.assigns.timeout_ref)

    user_input =
      numbers
      |> Enum.filter(fn {k, _} -> Regex.match?(~r/^\d+$/, k) end)
      |> Enum.sort_by(fn {k, _} -> String.to_integer(k) end)
      |> Enum.map(fn {_k, v} ->
        case Integer.parse(v) do
          {int, _} -> int
          :error -> nil
        end
      end)

    {correct, wrong, omitted} =
      ReverseSequence.evaluate_individual_responses(user_input, socket.assigns.sequence)

    was_full_correct =
      Enum.all?(user_input, &(!is_nil(&1) and &1 != "")) and
        ReverseSequence.validate_response(user_input, socket.assigns.sequence) == :correct

    new_full_sequence =
      if was_full_correct, do: socket.assigns.full_sequence + 1, else: socket.assigns.full_sequence

    reaction_time = System.monotonic_time() - (socket.assigns.start_time || System.monotonic_time())
    reaction_time_ms = System.convert_time_unit(reaction_time, :native, :millisecond)

    new_attempts = socket.assigns.attempts + 1
    new_total_reaction_time = socket.assigns.total_reaction_time + reaction_time_ms

    new_correct = socket.assigns.correct + correct
    new_wrong = socket.assigns.wrong + wrong
    new_omitted = socket.assigns.omitted + omitted

    if new_attempts >= socket.assigns.total_attempts do
      send(self(), :save_results)

      {:noreply,
       assign(socket,
         correct: new_correct,
         wrong: new_wrong,
         omitted: new_omitted,
         total_reaction_time: new_total_reaction_time,
         full_sequence: new_full_sequence,
         game_finished: true,
         timeout_ref: nil
       )}
    else
      send(self(), :start_round)

      {:noreply,
       assign(socket,
         correct: new_correct,
         wrong: new_wrong,
         omitted: new_omitted,
         full_sequence: new_full_sequence,
         attempts: new_attempts,
         total_reaction_time: new_total_reaction_time,
         timeout_ref: nil
       )}
    end
  end

  defp save_final_result(socket) do
    task_id = Beam.Exercices.TaskList.task_id(:reverse_sequence)

    total_attempts = socket.assigns.correct + socket.assigns.wrong + socket.assigns.omitted
    accuracy = if total_attempts > 0, do: socket.assigns.correct / total_attempts, else: 0.0

    sequence_length = length(socket.assigns.sequence)

    avg_reaction_time =
      if total_attempts > 0,
        do: (socket.assigns.total_reaction_time / total_attempts) * sequence_length,
        else: 0

    result_entry = %{
      user_id: socket.assigns.user_id,
      task_id: task_id,
      correct: socket.assigns.correct,
      wrong: socket.assigns.wrong,
      omitted: socket.assigns.omitted,
      accuracy: accuracy,
      reaction_time: avg_reaction_time,
      full_sequence: socket.assigns.full_sequence
    }

    case Repo.insert(Result.changeset(%Result{}, result_entry)) do
      {:ok, result} -> {task_id, result.id}
      {:error, _reason} -> {task_id, nil}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 flex items-center justify-center bg-white">
      <%= if @game_finished do %>
        <p class="text-2xl font-bold text-gray-800">A calcular resultados...</p>
      <% else %>
        <%= if @preparing do %>
          <p class="text-2xl font-bold text-gray-800 animate-pulse">A preparar exercício...</p>
        <% else %>
          <%= if @show_sequence do %>
            <p class="text-4xl font-bold text-gray-800">
              <%= Enum.join(@sequence, " ") %>
            </p>
          <% else %>
            <form phx-submit="submit" phx-change="update_input">
              <div class="flex space-x-2">
                <%= for {_, i} <- Enum.with_index(@sequence) do %>
                  <input
                    type="text"
                    name={"numbers[#{i}]"}
                    inputmode="numeric"
                    pattern="[0-9]"
                    maxlength="1"
                    class="w-12 h-12 text-center border border-gray-400 rounded-md"
                    value={Enum.at(@user_input, i) || ""}
                  />
                <% end %>
              </div>
              <button type="submit" class="mt-4 px-4 py-2 bg-blue-500 text-white rounded-md">Enviar</button>
            </form>
          <% end %>
        <% end %>
      <% end %>
    </div>
    """
  end
end

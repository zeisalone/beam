defmodule BeamWeb.Tasks.ReverseSequenceLive do
  use BeamWeb, :live_view
  alias Beam.Exercices.Tasks.ReverseSequence
  alias Beam.Repo
  alias Beam.Exercices.Result

  @sequence_duration 7500
  @response_timeout 10_000
  @total_attempts 5

  def mount(_params, session, socket) do
    current_user = Map.get(session, "current_user", nil)

    task_id = Map.get(session, "task_id", nil)
    live_action = Map.get(session, "live_action", "training") |> maybe_to_atom()
    difficulty = Map.get(session, "difficulty") |> maybe_to_atom() || :medio

    if current_user do
      sequence = ReverseSequence.generate_sequence(difficulty)

      if connected?(socket), do: Process.send_after(self(), :hide_sequence, @sequence_duration)

      {:ok,
       assign(socket,
         current_user: current_user,
         user_id: current_user.id,
         task_id: task_id,
         sequence: sequence,
         user_input: [],
         correct: 0,
         wrong: 0,
         omitted: 0,
         attempts: 0,
         start_time: nil,
         total_reaction_time: 0,
         timeout_ref: nil,
         live_action: live_action,
         difficulty: difficulty,
         show_sequence: true,
         full_screen?: true,
         game_finished: false
       )}
    else
      {:ok, push_navigate(socket, to: "/tasks")}
    end
  end

  defp maybe_to_atom(nil), do: nil
  defp maybe_to_atom(value) when is_binary(value), do: String.to_existing_atom(value)
  defp maybe_to_atom(value), do: value

  def handle_info(:hide_sequence, socket) do
    timeout_ref = Process.send_after(self(), :timeout, @response_timeout)
    {:noreply, assign(socket, show_sequence: false, start_time: System.monotonic_time(), timeout_ref: timeout_ref)}
  end

  def handle_info(:timeout, socket) do
    if socket.assigns.game_finished do
      {:noreply, socket}
    else
      user_input =
        socket.assigns.user_input ++ List.duplicate(nil, length(socket.assigns.sequence) - length(socket.assigns.user_input))
      {correct, wrong, omitted} =
        ReverseSequence.evaluate_individual_responses(user_input, socket.assigns.sequence)

      reaction_time_ms = @response_timeout
      new_attempts = socket.assigns.attempts + 1
      new_total_reaction_time = socket.assigns.total_reaction_time + reaction_time_ms

      new_correct = socket.assigns.correct + correct
      new_wrong = socket.assigns.wrong + wrong
      new_omitted = socket.assigns.omitted + omitted

      if new_attempts >= @total_attempts do
        send(self(), :save_results)

        {:noreply,
         assign(socket,
           correct: new_correct,
           wrong: new_wrong,
           omitted: new_omitted,
           total_reaction_time: new_total_reaction_time,
           game_finished: true
         )}
      else
        new_sequence = ReverseSequence.generate_sequence(socket.assigns.difficulty)
        Process.send_after(self(), :hide_sequence, @sequence_duration)

        {:noreply,
         assign(socket,
           correct: new_correct,
           wrong: new_wrong,
           omitted: new_omitted,
           attempts: new_attempts,
           total_reaction_time: new_total_reaction_time,
           sequence: new_sequence,
           user_input: List.duplicate("", length(new_sequence)),
           show_sequence: true,
           start_time: System.monotonic_time(),
           timeout_ref: nil
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

    reaction_time = System.monotonic_time() - (socket.assigns.start_time || System.monotonic_time())
    reaction_time_ms = System.convert_time_unit(reaction_time, :native, :millisecond)

    new_attempts = socket.assigns.attempts + 1
    new_total_reaction_time = socket.assigns.total_reaction_time + reaction_time_ms

    new_correct = socket.assigns.correct + correct
    new_wrong = socket.assigns.wrong + wrong
    new_omitted = socket.assigns.omitted + omitted

    if new_attempts >= @total_attempts do
      send(self(), :save_results)

      {:noreply,
       assign(socket,
         correct: new_correct,
         wrong: new_wrong,
         omitted: new_omitted,
         total_reaction_time: new_total_reaction_time,
         game_finished: true,
         timeout_ref: nil
       )}
    else
      new_sequence = ReverseSequence.generate_sequence(socket.assigns.difficulty)
      Process.send_after(self(), :hide_sequence, @sequence_duration)

      {:noreply,
       assign(socket,
         correct: new_correct,
         wrong: new_wrong,
         omitted: new_omitted,
         attempts: new_attempts,
         total_reaction_time: new_total_reaction_time,
         sequence: new_sequence,
         user_input: List.duplicate("", length(new_sequence)),
         show_sequence: true,
         start_time: System.monotonic_time(),
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
          reaction_time: avg_reaction_time
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
    </div>
    """
  end
end

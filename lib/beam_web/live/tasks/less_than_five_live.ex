defmodule BeamWeb.Tasks.LessThanFiveLive do
  use BeamWeb, :live_view
  alias Beam.Exercices.Tasks.LessThanFive
  alias Beam.Repo
  alias Beam.Exercices.Result

  @total_trials 20

  def mount(_params, session, socket) do
    current_user = Map.get(session, "current_user", nil)

    task_id = Map.get(session, "task_id", nil)
    live_action = Map.get(session, "live_action", "training") |> maybe_to_atom()
    difficulty = Map.get(session, "difficulty", "facil") |> maybe_to_atom()
    full_screen = Map.get(session, "full_screen?", true)

    {interval, blank_interval} = interval_settings(difficulty)

    if current_user do
      if connected?(socket), do: Process.send_after(self(), :next_number, 0)

      {:ok,
       assign(socket,
         current_user: current_user,
         user_id: current_user.id,
         task_id: task_id,
         sequence: LessThanFive.generate_sequence(@total_trials, difficulty),
         current_index: -1,
         correct: 0,
         wrong: 0,
         omitted: 0,
         total_reaction_time: 0,
         awaiting_response: false,
         show_number: false,
         live_action: live_action,
         difficulty: difficulty,
         total_trials: @total_trials,
         user_pressed: false,
         interval: interval,
         blank_interval: blank_interval,
         current_number: nil,
         current_color: :black,
         full_screen?: full_screen,
         reaction_start_time: nil
       )}
    else
      {:ok, push_navigate(socket, to: "/tasks")}
    end
  end

  defp interval_settings(:facil), do: {2000, 2000}
  defp interval_settings(:medio), do: {800, 800}
  defp interval_settings(:dificil), do: {800, 800}
  defp interval_settings(_), do: {1000, 1000}

  def handle_info(:next_number, socket) do
    if socket.assigns.current_index + 1 >= @total_trials do
      send(self(), :save_results)
      {:noreply, socket}
    else
      Process.send_after(self(), :hide_number, socket.assigns.interval)

      %{value: number, color: color} =
        Enum.at(socket.assigns.sequence, socket.assigns.current_index + 1, %{
          value: "",
          color: :black
        })

      {:noreply,
       assign(socket,
         current_index: socket.assigns.current_index + 1,
         show_number: true,
         awaiting_response: true,
         user_pressed: false,
         current_number: number,
         current_color: color,
         reaction_start_time: System.monotonic_time()
       )}
    end
  end

  def handle_info(:hide_number, socket) do
    Process.send_after(self(), :next_number, socket.assigns.blank_interval)

    number = socket.assigns.current_number

    result =
      if socket.assigns.awaiting_response do
        LessThanFive.validate_response(
          false,
          number,
          socket.assigns.interval,
          socket.assigns.interval
        )
      else
        nil
      end

    update_counts =
      case result do
        :correct -> %{correct: socket.assigns.correct + 1}
        :wrong -> %{wrong: socket.assigns.wrong + 1}
        :omitted -> %{omitted: socket.assigns.omitted + 1}
        _ -> %{}
      end

    {:noreply,
     assign(socket,
       show_number: false,
       awaiting_response: false,
       correct: update_counts[:correct] || socket.assigns.correct,
       wrong: update_counts[:wrong] || socket.assigns.wrong,
       omitted: update_counts[:omitted] || socket.assigns.omitted
     )}
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

  def handle_event("key_pressed", %{"key" => key}, socket) do
    if key == " " and socket.assigns.awaiting_response do
      reaction_time =
        (System.monotonic_time() - socket.assigns.reaction_start_time)
        |> System.convert_time_unit(:native, :millisecond)

      number = socket.assigns.current_number
      max_time = socket.assigns.interval

      result = LessThanFive.validate_response(true, number, reaction_time, max_time)

      update_counts =
        case result do
          :correct -> %{correct: socket.assigns.correct + 1}
          :wrong -> %{wrong: socket.assigns.wrong + 1}
          :omitted -> %{omitted: socket.assigns.omitted + 1}
        end

      {:noreply,
       assign(socket,
         correct: update_counts[:correct] || socket.assigns.correct,
         wrong: update_counts[:wrong] || socket.assigns.wrong,
         omitted: update_counts[:omitted] || socket.assigns.omitted,
         total_reaction_time: socket.assigns.total_reaction_time + reaction_time,
         awaiting_response: false,
         user_pressed: true
       )}
    else
      {:noreply, socket}
    end
  end

  defp save_final_result(socket) do
    task_id = Beam.Exercices.TaskList.task_id(:less_than_five)
    total_attempts = socket.assigns.correct + socket.assigns.wrong + socket.assigns.omitted
    accuracy = if total_attempts > 0, do: socket.assigns.correct / total_attempts, else: 0.0

    avg_reaction_time =
      if socket.assigns.correct > 0,
        do: socket.assigns.total_reaction_time / socket.assigns.correct,
        else: 0

    result_entry = %{
      user_id: socket.assigns.user_id,
      task_id: task_id,
      correct: socket.assigns.correct,
      wrong: socket.assigns.wrong,
      omitted: socket.assigns.omitted,
      reaction_time: avg_reaction_time,
      accuracy: accuracy
    }

    case Repo.insert(Result.changeset(%Result{}, result_entry)) do
      {:ok, result} -> {task_id, result.id}
      {:error, _reason} -> {task_id, nil}
    end
  end

  defp maybe_to_atom(nil), do: nil
  defp maybe_to_atom(value) when is_binary(value), do: String.to_existing_atom(value)
  defp maybe_to_atom(_), do: nil

  def render(assigns) do
    color_class =
      case assigns.difficulty do
        :dificil ->
          case assigns.current_color do
            :red -> "text-red-600"
            :green -> "text-green-600"
            _ -> "text-black"
          end

        _ ->
          "text-black"
      end

    ~H"""
    <div
      class="fixed inset-0 w-screen h-screen flex items-center justify-center bg-white"
      phx-window-keydown="key_pressed"
      phx-capture-keydown
    >
      <%= if assigns.current_index < @total_trials do %>
        <%= if @show_number do %>
          <p class={"text-5xl font-bold transition-colors duration-200 " <> if @user_pressed, do: "text-gray-500", else: color_class}>
            {@current_number}
          </p>
        <% else %>
          <p class="text-5xl font-bold text-gray-300">+</p>
        <% end %>
      <% else %>
        <p class="text-2xl font-bold text-gray-800">A calcular resultados...</p>
      <% end %>
    </div>
    """
  end
end

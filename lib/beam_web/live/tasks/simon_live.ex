defmodule BeamWeb.Tasks.SimonLive do
  use BeamWeb, :live_view
  alias Beam.Exercices.Tasks.Simon
  alias Beam.Exercices.Result
  alias Beam.Repo

  @sequence_delay 600
  @max_duration Simon.time_limit_ms()

  def mount(_params, session, socket) do
    current_user = Map.get(session, "current_user")
    difficulty = ensure_difficulty(Map.get(session, "difficulty"))
    live_action = Map.get(session, "live_action") |> to_existing_atom(:training)
    task_id = Map.get(session, "task_id")
    full_screen = Map.get(session, "full_screen?", true)

    if connected?(socket), do: Process.send_after(self(), :prepare_task, 0)

    {:ok,
     assign(socket,
       current_user: current_user,
       user_id: current_user.id,
       task_id: task_id,
       difficulty: difficulty,
       live_action: live_action,
       full_screen?: full_screen,
       preparing_task: true,
       colors: [],
       sequence: [],
       user_input: [],
       correct: 0,
       errors: 0,
       total_reaction_time: 0,
       active_index: nil,
       locked_buttons: true,
       calculating_results: false,
       start_time: nil,
       shake_error?: false,
       time_remaining: @max_duration,
       timer_ref: nil
     )}
  end

  def handle_info(:prepare_task, socket) do
    Process.send_after(self(), :start_game, 2000)
    {:noreply, assign(socket, preparing_task: true)}
  end

  def handle_info(:start_game, socket) do
    colors = Simon.generate_colors(socket.assigns.difficulty)
    sequence = [Enum.random(0..(length(colors) - 1))]
    {:ok, timer} = :timer.send_interval(1000, self(), :tick)
    Process.send_after(self(), :timeout, @max_duration)

    {:noreply,
     assign(socket,
       colors: colors,
       sequence: sequence,
       user_input: [],
       preparing_task: false,
       locked_buttons: true,
       timer_ref: timer
     )
     |> animate_sequence()}
  end

  def handle_info({:animate_sequence, sequence, idx}, socket) do
    if idx < length(sequence) do
      active = Enum.at(sequence, idx)
      Process.send_after(self(), {:clear_highlight, sequence, idx}, @sequence_delay)
      {:noreply, assign(socket, active_index: active)}
    else
      {:noreply,
       assign(socket,
         active_index: nil,
         locked_buttons: false,
         start_time: System.monotonic_time(:millisecond)
       )}
    end
  end

  def handle_info({:clear_highlight, sequence, idx}, socket) do
    Process.send_after(self(), {:animate_sequence, sequence, idx + 1}, 100)
    {:noreply, assign(socket, active_index: nil)}
  end

  def handle_info(:clear_error_animation, socket) do
    {:noreply, assign(socket, shake_error?: false)}
  end

  def handle_info(:start_new_sequence_after_error, socket) do
    {:noreply, animate_sequence(socket)}
  end

  def handle_info(:tick, socket) do
    new_time = socket.assigns.time_remaining - 1000

    if new_time <= 0 do
      send(self(), :timeout)
      {:noreply, socket}
    else
      {:noreply, assign(socket, time_remaining: new_time)}
    end
  end

  def handle_info(:timeout, socket) do
    if socket.assigns.timer_ref, do: :timer.cancel(socket.assigns.timer_ref)
    result_data =
      Simon.create_result_entry(
        socket.assigns.user_id,
        socket.assigns.task_id,
        socket.assigns.correct,
        socket.assigns.errors,
        socket.assigns.total_reaction_time,
        1
      )

    case Repo.insert(Result.changeset(%Result{}, result_data)) do
      {:ok, result} ->
        Beam.Exercices.save_training_attempt(
          socket.assigns.user_id,
          socket.assigns.task_id,
          result.id,
          socket.assigns.difficulty
        )

      {:error, _} ->
        :noop
    end

    {:noreply, push_navigate(socket, to: ~p"/results/aftertask?task_id=#{socket.assigns.task_id}")}
  end

  def handle_info(:save_results, socket) do
    if socket.assigns.timer_ref, do: :timer.cancel(socket.assigns.timer_ref)

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

    Process.sleep(2000)
    {:noreply, push_navigate(socket, to: ~p"/results/aftertask?task_id=#{task_id}")}
  end

  def handle_event("button_click", %{"index" => _}, %{assigns: %{locked_buttons: true}} = socket) do
    {:noreply, socket}
  end

  def handle_event("button_click", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    input = socket.assigns.user_input ++ [index]
    expected = Enum.slice(socket.assigns.sequence, 0, length(input))
    reaction_time = System.monotonic_time(:millisecond) - (socket.assigns.start_time || 0)

    if input == expected do
      if length(input) == length(socket.assigns.sequence) do
        if Simon.finished?(socket.assigns.correct + 1) do
          send(self(), :save_results)

          {:noreply,
           assign(socket,
             calculating_results: true,
             locked_buttons: true,
             correct: socket.assigns.correct + 1,
             total_reaction_time: socket.assigns.total_reaction_time + reaction_time
           )}
        else
          next_index = Enum.random(0..(length(socket.assigns.colors) - 1))
          new_sequence = socket.assigns.sequence ++ [next_index]

          socket =
            assign(socket,
              sequence: new_sequence,
              user_input: [],
              correct: socket.assigns.correct + 1,
              locked_buttons: true,
              total_reaction_time: socket.assigns.total_reaction_time + reaction_time
            )

          {:noreply, animate_sequence(socket)}
        end
      else
        {:noreply,
         assign(socket,
           user_input: input,
           total_reaction_time: socket.assigns.total_reaction_time + reaction_time
         )}
      end
    else
      new_sequence = [Enum.random(0..(length(socket.assigns.colors) - 1))]

      socket =
        assign(socket,
          errors: socket.assigns.errors + 1,
          user_input: [],
          sequence: new_sequence,
          correct: 0,
          locked_buttons: true,
          total_reaction_time: socket.assigns.total_reaction_time + reaction_time,
          shake_error?: true
        )

      Process.send_after(self(), :clear_error_animation, 1000)
      Process.send_after(self(), :start_new_sequence_after_error, 1000)

      {:noreply, socket}
    end
  end

  defp animate_sequence(socket) do
    send(self(), {:animate_sequence, socket.assigns.sequence, 0})
    socket
  end

  defp save_final_result(socket) do
    task_id = socket.assigns.task_id

    result_data =
      Simon.create_result_entry(
        socket.assigns.user_id,
        task_id,
        socket.assigns.correct,
        socket.assigns.errors,
        socket.assigns.total_reaction_time
      )

    case Repo.insert(Result.changeset(%Result{}, result_data)) do
      {:ok, result} -> {task_id, result.id}
      {:error, _} -> {task_id, nil}
    end
  end

  def render(assigns) do
    ~H"""
    <div class={"fixed inset-0 flex flex-col items-center justify-center bg-white transition-all duration-300 #{if @shake_error?, do: "animate-shake", else: ""}"}>
      <div class="absolute top-2 right-4 text-sm text-gray-500">
        <%= div(@time_remaining, 1000) %>s
      </div>

      <%= if @preparing_task do %>
        <p class="text-xl animate-pulse text-gray-700">A preparar tarefa...</p>
      <% else %>
        <%= if @calculating_results do %>
          <p class="text-2xl font-bold text-gray-800">A calcular resultados...</p>
        <% else %>
          <div class="flex flex-col items-center space-y-6">
            <div class="flex space-x-2">
              <%= for i <- 1..7 do %>
                <div class={"w-4 h-4 rounded-full border-2 #{dot_class(i, @correct, @shake_error?)}"}></div>
              <% end %>
            </div>
            <div class="p-4 border-[20px] border-gray-700 bg-gray-800 rounded-md shadow-xl">
              <div class={"grid gap-4 #{grid_class(@colors)}"}>
                <%= for {color, index} <- Enum.with_index(@colors) do %>
                  <button
                    phx-click="button_click"
                    phx-value-index={index}
                    class={"w-20 h-20 rounded-full shadow-inner border-2 #{color_to_class(color, index == @active_index, @locked_buttons)}"}
                  ></button>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp grid_class(colors) do
    case length(colors) do
      4 -> "grid-cols-2"
      6 -> "grid-cols-3"
      9 -> "grid-cols-3"
      _ -> "grid-cols-2"
    end
  end

  defp color_to_class(color, true, _), do: color_map(color)
  defp color_to_class(color, false, true), do: "#{color_map(color)} opacity-30"
  defp color_to_class(color, false, false), do: color_map(color)

  defp color_map("red"), do: "bg-red-500"
  defp color_map("blue"), do: "bg-blue-500"
  defp color_map("green"), do: "bg-green-500"
  defp color_map("yellow"), do: "bg-yellow-400"
  defp color_map("purple"), do: "bg-purple-500"
  defp color_map("orange"), do: "bg-orange-400"
  defp color_map("teal"), do: "bg-teal-400"
  defp color_map("pink"), do: "bg-pink-400"
  defp color_map("brown"), do: "bg-yellow-800"
  defp color_map(_), do: "bg-gray-300"

  defp dot_class(_, _, true), do: "bg-red-500"
  defp dot_class(i, correct, false) when i <= correct, do: "bg-green-500"
  defp dot_class(_, _, _), do: "bg-gray-300"

  defp to_existing_atom(nil, default), do: default

  defp to_existing_atom(str, default) when is_binary(str) do
    try do
      String.to_existing_atom(str)
    rescue
      _ -> default
    end
  end

  defp to_existing_atom(val, _default), do: val

  defp ensure_difficulty(value) do
    to_existing_atom(value, :medio)
    |> case do
      x when x in [:facil, :medio, :dificil] -> x
      _ -> :medio
    end
  end
end

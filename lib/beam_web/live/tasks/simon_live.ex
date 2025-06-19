defmodule BeamWeb.Tasks.SimonLive do
  use BeamWeb, :live_view
  alias Beam.Exercices.Tasks.Simon
  alias Beam.Exercices.Result
  alias Beam.Repo

  @sequence_delay 600

  def mount(_params, session, socket) do
    current_user = Map.get(session, "current_user")
    live_action = Map.get(session, "live_action") |> to_existing_atom(:training)
    difficulty = Map.get(session, "difficulty") |> to_existing_atom(:medio)
    task_id = Map.get(session, "task_id")
    full_screen = Map.get(session, "full_screen?", true)
    raw_config = Map.get(session, "config")

    {difficulty_or_config, max_duration} =
      case {live_action, difficulty} do
        {:training, :criado} when is_map(raw_config) ->
          config = Map.merge(Simon.default_config(), atomize_keys(raw_config))
          {config, Simon.time_limit_ms(config)}

        _ ->
          {difficulty, Simon.time_limit_ms()}
      end

    if connected?(socket), do: Process.send_after(self(), :prepare_task, 0)

    {:ok,
     assign(socket,
       current_user: current_user,
       user_id: current_user.id,
       task_id: task_id,
       difficulty: difficulty,
       difficulty_or_config: difficulty_or_config,
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
       time_remaining: max_duration,
       timer_ref: nil,
       timeout_ref: nil,
       paused: false,
       pause_info: nil
     )}
  end

  def handle_info(:prepare_task, socket) do
    Process.send_after(self(), :start_game, 2000)
    {:noreply, assign(socket, preparing_task: true)}
  end

  def handle_info(:start_game, socket) do
    config = socket.assigns.difficulty_or_config
    colors = Simon.generate_colors(config)
    sequence = [Enum.random(0..(length(colors) - 1))]
    {:ok, timer_ref} = :timer.send_interval(1000, self(), :tick)
    timeout_ref = Process.send_after(self(), :timeout, Simon.time_limit_ms(config))

    {:noreply,
     assign(socket,
       colors: colors,
       sequence: sequence,
       user_input: [],
       preparing_task: false,
       locked_buttons: true,
       timer_ref: timer_ref,
       timeout_ref: timeout_ref,
       time_remaining: Simon.time_limit_ms(config)
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
    if socket.assigns.paused do
      {:noreply, socket}
    else
      new_time = socket.assigns.time_remaining - 1000
      if new_time <= 0 do
        send(self(), :timeout)
        {:noreply, assign(socket, time_remaining: 0)}
      else
        {:noreply, assign(socket, time_remaining: new_time)}
      end
    end
  end

  def handle_info(:timeout, socket) do
    if socket.assigns.timer_ref, do: :timer.cancel(socket.assigns.timer_ref)
    if socket.assigns.timeout_ref, do: Process.cancel_timer(socket.assigns.timeout_ref)
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

      {:error, _} -> :noop
    end

    {:noreply, push_navigate(socket, to: ~p"/results/aftertask?task_id=#{socket.assigns.task_id}")}
  end

  def handle_info(:save_results, socket) do
    if socket.assigns.timer_ref, do: :timer.cancel(socket.assigns.timer_ref)
    if socket.assigns.timeout_ref, do: Process.cancel_timer(socket.assigns.timeout_ref)
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

  def handle_event("button_click", %{"index" => _}, %{assigns: %{locked_buttons: true}} = socket), do: {:noreply, socket}

  def handle_event("button_click", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    input = socket.assigns.user_input ++ [index]
    expected = Enum.slice(socket.assigns.sequence, 0, length(input))
    reaction_time = System.monotonic_time(:millisecond) - (socket.assigns.start_time || 0)

    if input == expected do
      if length(input) == length(socket.assigns.sequence) do
        if Simon.finished?(socket.assigns.correct + 1, socket.assigns.difficulty_or_config) do
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

  def handle_event("toggle_pause", _params, socket) do
    paused = !socket.assigns.paused

    if paused do
      if socket.assigns.timer_ref, do: :timer.cancel(socket.assigns.timer_ref)
      if socket.assigns.timeout_ref, do: Process.cancel_timer(socket.assigns.timeout_ref)
      pause_info = %{
        time_remaining: socket.assigns.time_remaining
      }
      {:noreply, assign(socket, paused: true, pause_info: pause_info, timer_ref: nil, timeout_ref: nil)}
    else
      %{time_remaining: time_left} = socket.assigns.pause_info
      {:ok, timer_ref} = :timer.send_interval(1000, self(), :tick)
      timeout_ref = Process.send_after(self(), :timeout, max(time_left, 1))
      {:noreply,
        assign(socket,
          paused: false,
          pause_info: nil,
          timer_ref: timer_ref,
          timeout_ref: timeout_ref,
          time_remaining: time_left
        )}
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

      <%= if @current_user && @current_user.type == "Terapeuta" && !@preparing_task && !@calculating_results do %>
        <button
          type="button"
          phx-click="toggle_pause"
          class={"absolute top-12 right-4 z-30 bg-yellow-100 border-2 border-yellow-400 rounded-full p-2 hover:bg-yellow-200 transition " <>
                (if @paused, do: "ring-2 ring-yellow-200", else: "")}
          title={if @paused, do: "Retomar", else: "Pausar"}
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="w-7 h-7 text-yellow-700" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <%= if @paused do %>
              <polygon points="10,8 16,12 10,16" fill="currentColor"/>
            <% else %>
              <rect x="6" y="5" width="4" height="14" rx="1"/><rect x="14" y="5" width="4" height="14" rx="1"/>
            <% end %>
          </svg>
        </button>
      <% end %>

      <%= if @paused do %>
        <div class="fixed inset-0 z-40 bg-black bg-opacity-70 flex flex-col justify-center items-center">
          <button
            phx-click="toggle_pause"
            class="flex flex-col items-center group focus:outline-none"
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="w-28 h-28 mb-4 text-yellow-400 group-hover:text-yellow-300 transition" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2" fill="none"/>
              <polygon points="10,8 16,12 10,16" fill="currentColor"/>
            </svg>
            <span class="text-4xl font-black text-yellow-200 group-hover:text-yellow-100">Retomar</span>
          </button>
          <span class="mt-4 text-white text-lg">Clique no botão acima para continuar o exercício</span>
        </div>
      <% end %>

      <%= if @preparing_task do %>
        <p class="text-xl animate-pulse text-gray-700">A preparar tarefa...</p>
      <% else %>
        <%= if @calculating_results do %>
          <p class="text-2xl font-bold text-gray-800">A calcular resultados...</p>
        <% else %>
          <div class="flex flex-col items-center space-y-6">
            <div class="flex space-x-2">
              <%= for i <- 1..sequence_length(@difficulty_or_config) do %>
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

  defp sequence_length(%{sequence_length: len}), do: len
  defp sequence_length(_), do: 7

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

  defp atomize_keys(map) do
    for {k, v} <- map, into: %{} do
      key = if is_binary(k), do: String.to_existing_atom(k), else: k
      {key, v}
    end
  end
end

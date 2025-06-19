defmodule BeamWeb.Tasks.LessThanFiveLive do
  use BeamWeb, :live_view
  alias Beam.Exercices.Tasks.LessThanFive
  alias Beam.Repo
  alias Beam.Exercices.Result

  @default_total_trials 20
  @default_display_times %{
    facil: 2000,
    medio: 800,
    dificil: 800,
    default: 1000
  }

  def mount(_params, session, socket) do
    current_user = Map.get(session, "current_user", nil)
    task_id = Map.get(session, "task_id", nil)
    live_action = Map.get(session, "live_action", "training") |> maybe_to_atom()
    difficulty = Map.get(session, "difficulty", "facil") |> maybe_to_atom()
    full_screen = Map.get(session, "full_screen?", true)

    raw_config = Map.get(session, "config", %{})

    config =
      Map.merge(
        LessThanFive.default_config(),
        if(is_map(raw_config), do: atomize_keys(raw_config), else: %{})
      )

    total_trials = Map.get(config, :total_trials, @default_total_trials)
    interval = Map.get(@default_display_times, difficulty, @default_display_times.default)

    if current_user do
      if connected?(socket), do: Process.send_after(self(), :next_number, 0)

      {:ok,
       assign(socket,
         current_user: current_user,
         user_id: current_user.id,
         task_id: task_id,
         sequence: LessThanFive.generate_sequence(total_trials, difficulty),
         current_index: -1,
         correct: 0,
         wrong: 0,
         omitted: 0,
         total_reaction_time: 0,
         awaiting_response: false,
         show_number: false,
         live_action: live_action,
         difficulty: difficulty,
         total_trials: total_trials,
         user_pressed: false,
         interval: interval,
         blank_interval: interval,
         current_number: nil,
         current_color: :black,
         full_screen?: full_screen,
         reaction_start_time: nil,
         paused: false,
         pause_info: nil,
         timer_phase: nil,
         timer_start: nil,
         time_left: nil
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

  def handle_info(:next_number, socket) do
    if socket.assigns.paused do
      {:noreply, socket}
    else
      if socket.assigns.current_index + 1 >= socket.assigns.total_trials do
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
           reaction_start_time: System.monotonic_time(),
           timer_phase: :show,
           timer_start: System.monotonic_time(:millisecond),
           time_left: nil
         )}
      end
    end
  end

  def handle_info(:hide_number, socket) do
    if socket.assigns.paused do
      {:noreply, socket}
    else
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
         omitted: update_counts[:omitted] || socket.assigns.omitted,
         timer_phase: :blank,
         timer_start: System.monotonic_time(:millisecond),
         time_left: nil
       )}
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

  def handle_event("key_pressed", %{"key" => key}, socket) do
    if socket.assigns.paused do
      {:noreply, socket}
    else
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
  end

  def handle_event("toggle_pause", _params, socket) do
    can_pause =
      socket.assigns.current_user.type == "Terapeuta" and
        socket.assigns.current_index < socket.assigns.total_trials

    if can_pause do
      paused = !socket.assigns.paused

      if paused do
        now = System.monotonic_time(:millisecond)
        phase = socket.assigns.timer_phase
        timer_start = socket.assigns.timer_start
        time_passed = if timer_start, do: now - timer_start, else: 0

        time_left =
          case phase do
            :show -> max(socket.assigns.interval - time_passed, 1)
            :blank -> max(socket.assigns.blank_interval - time_passed, 1)
            _ -> nil
          end

        {:noreply, assign(socket, paused: true, time_left: time_left)}
      else
        phase = socket.assigns.timer_phase
        time_left = socket.assigns.time_left || 1

        if socket.assigns.current_index < socket.assigns.total_trials do
          msg =
            case phase do
              :show -> :hide_number
              :blank -> :next_number
              _ -> nil
            end

          if msg, do: Process.send_after(self(), msg, time_left)
        end

        {:noreply, assign(socket, paused: false, timer_start: System.monotonic_time(:millisecond), time_left: nil)}
      end
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

        _ -> "text-black"
      end

    ~H"""
    <div
      class="fixed inset-0 w-screen h-screen flex items-center justify-center bg-white"
      phx-window-keydown="key_pressed"
      phx-capture-keydown
    >
      <%= if @current_user.type == "Terapeuta" and @current_index < @total_trials do %>
        <button
          type="button"
          phx-click="toggle_pause"
          class="absolute right-6 top-6 z-40 bg-yellow-100 border-2 border-yellow-400 rounded-full p-2 hover:bg-yellow-200 transition"
          title={if @paused, do: "Retomar", else: "Pausar"}
        >
          <.icon name={if @paused, do: "hero-play-mini", else: "hero-pause-mini"} class="w-8 h-8 text-yellow-700" />
        </button>
      <% end %>

      <%= if @paused do %>
        <div class="fixed inset-0 z-50 bg-black bg-opacity-70 flex flex-col justify-center items-center">
          <button
            phx-click="toggle_pause"
            class="flex flex-col items-center group focus:outline-none"
          >
            <.icon name="hero-play-circle" class="w-28 h-28 mb-4 text-yellow-400 group-hover:text-yellow-300 transition" />
            <span class="text-4xl font-black text-yellow-200 group-hover:text-yellow-100">Retomar</span>
          </button>
          <span class="mt-4 text-white text-lg">Clique no botão acima para continuar o exercício</span>
        </div>
      <% end %>

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

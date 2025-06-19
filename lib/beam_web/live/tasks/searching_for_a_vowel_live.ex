defmodule BeamWeb.Tasks.SearchingForAVowelLive do
  use BeamWeb, :live_view
  alias Beam.Exercices.Tasks.SearchingForAVowel
  alias Beam.Repo
  alias Beam.Exercices.Result

  @intro_duration 3000

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

    full_screen = Map.get(session, "full_screen?", true)
    raw_config = Map.get(session, "config", %{})

    config =
      Map.merge(
        SearchingForAVowel.default_config(),
        if(is_map(raw_config), do: atomize_keys(raw_config), else: %{})
      )

    phase_duration = Map.get(config, :phase_duration)
    cycle_duration = Map.get(config, :cycle_duration)
    total_phases = Map.get(config, :total_phases)

    if current_user do
      chosen_difficulty =
        if is_nil(difficulty) do
          SearchingForAVowel.choose_level_by_age(current_user.id)
        else
          difficulty
        end

      if connected?(socket), do: Process.send_after(self(), :prepare_task, 0)

      target = Map.put(SearchingForAVowel.generate_target(), :position, "up")

      {:ok,
       assign(socket,
         current_user: current_user,
         user_id: current_user.id,
         task_id: task_id,
         target: target,
         phase: [],
         correct: 0,
         wrong: 0,
         omitted: 0,
         total_reaction_time: 0,
         current_phase_start: nil,
         user_response: nil,
         current_phase_index: 1,
         awaiting_phase: false,
         results: [],
         calculating_results: false,
         in_cycle: false,
         live_action: live_action,
         difficulty: chosen_difficulty,
         full_screen?: full_screen,
         preparing_task: true,
         show_intro: false,
         phase_duration: phase_duration,
         cycle_duration: cycle_duration,
         total_phases: total_phases,
         config: config,
         paused: false,
         pause_info: nil,
         timer_ref: nil,
         timer_start: nil
       )}
    else
      {:ok, push_navigate(socket, to: "/tasks")}
    end
  end

  defp atomize_keys(map) do
    for {k, v} <- map, into: %{} do
      key = if is_binary(k), do: String.to_existing_atom(k), else: k
      value =
        if key == :num_distractors_list and is_binary(v) do
          v
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.map(&String.to_integer/1)
        else
          v
        end
      {key, value}
    end
  end

  defp maybe_to_atom(nil), do: nil
  defp maybe_to_atom(value) when is_binary(value), do: String.to_existing_atom(value)
  defp maybe_to_atom(value), do: value

  defp cancel_if_ref(timer_ref) when is_reference(timer_ref), do: Process.cancel_timer(timer_ref)
  defp cancel_if_ref(_), do: :ok

  defp time_left(:in_phase, assigns) do
    time_used = System.monotonic_time(:millisecond) - (assigns[:timer_start] || System.monotonic_time(:millisecond))
    max(assigns.phase_duration - time_used, 1)
  end

  def handle_info(:prepare_task, socket) do
    target = Map.put(SearchingForAVowel.generate_target(), :position, "up")
    Process.send_after(self(), :start_intro, 1000)
    {:noreply, assign(socket, target: target, preparing_task: false, show_intro: true)}
  end

  def handle_info(:start_intro, socket) do
    Process.send_after(self(), :start_phase, @intro_duration)
    {:noreply, socket}
  end

  def handle_info(:start_phase, socket) do
    phase =
      if socket.assigns.difficulty == :criado do
        SearchingForAVowel.generate_phase(socket.assigns.target, :criado, socket.assigns.config)
      else
        SearchingForAVowel.generate_phase(socket.assigns.target, socket.assigns.difficulty)
      end

    cancel_if_ref(socket.assigns.timer_ref)
    ref = Process.send_after(self(), :start_cycle, socket.assigns.phase_duration)

    {:noreply,
     assign(socket,
       phase: phase,
       current_phase_start: System.monotonic_time(),
       in_cycle: false,
       show_intro: false,
       paused: false,
       pause_info: nil,
       timer_ref: ref,
       timer_start: System.monotonic_time(:millisecond)
     )}
  end

  def handle_info(:start_cycle, socket) do
    cancel_if_ref(socket.assigns.timer_ref)
    ref = Process.send_after(self(), :next_phase, socket.assigns.cycle_duration)
    {:noreply, assign(socket, phase: [], in_cycle: true, timer_ref: ref, timer_start: System.monotonic_time(:millisecond))}
  end

  def handle_info(:next_phase, socket) do
    cancel_if_ref(socket.assigns.timer_ref)
    was_omitted = socket.assigns.user_response == nil
    reaction_time = if was_omitted, do: socket.assigns.phase_duration, else: 0

    if socket.assigns.current_phase_index >= socket.assigns.total_phases do
      send(self(), :save_results)
      {:noreply, assign(socket, calculating_results: true)}
    else
      Process.send_after(self(), :start_phase, 0)
      new_results = [%{result: :omitted, reaction_time: reaction_time} | socket.assigns.results]

      {:noreply,
       assign(socket,
         omitted: if(was_omitted, do: socket.assigns.omitted + 1, else: socket.assigns.omitted),
         total_reaction_time: socket.assigns.total_reaction_time + reaction_time,
         user_response: nil,
         current_phase_index: socket.assigns.current_phase_index + 1,
         results: new_results
       )}
    end
  end

  def handle_info(:save_results, socket) do
    {task_id, result_id} = save_final_result(socket)

    case socket.assigns.live_action do
      :test -> Beam.Exercices.save_test_attempt(socket.assigns.user_id, task_id, result_id)
      :training -> Beam.Exercices.save_training_attempt(socket.assigns.user_id, task_id, result_id, socket.assigns.difficulty)
    end

    Process.sleep(5000)
    {:noreply, push_navigate(socket, to: ~p"/results/aftertask?task_id=#{task_id}")}
  end

  def handle_event("toggle_pause", _params, socket) do
    can_pause =
      socket.assigns.current_user.type == "Terapeuta" and
        not socket.assigns.in_cycle and
        not socket.assigns.preparing_task and
        not socket.assigns.show_intro and
        not socket.assigns.calculating_results

    if can_pause do
      paused = !socket.assigns.paused
      if paused do
        time_left = time_left(:in_phase, socket.assigns)
        cancel_if_ref(socket.assigns.timer_ref)
        {:noreply, assign(socket, paused: true, pause_info: %{time_left: time_left})}
      else
        %{time_left: time_left} = socket.assigns.pause_info || %{time_left: nil}
        ref = Process.send_after(self(), :start_cycle, time_left)
        {:noreply, assign(socket, paused: false, pause_info: nil, timer_ref: ref, timer_start: System.monotonic_time(:millisecond))}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("vowel_click", %{"vowel" => vowel, "color" => color}, socket) do
    if socket.assigns.in_cycle or socket.assigns.paused, do: {:noreply, socket}, else: register_click(vowel, color, socket)
  end

  defp register_click(vowel, color, socket) do
    reaction_time =
      (System.monotonic_time() - socket.assigns.current_phase_start)
      |> System.convert_time_unit(:native, :millisecond)

    clicked = %{vowel: vowel, color: color}
    result = SearchingForAVowel.validate_response(clicked, socket.assigns.target)

    updated =
      case result do
        :correct -> %{correct: socket.assigns.correct + 1}
        :wrong -> %{wrong: socket.assigns.wrong + 1}
      end

    cancel_if_ref(socket.assigns.timer_ref)
    ref = Process.send_after(self(), :start_cycle, 0)

    {:noreply,
     assign(socket,
       user_response: clicked,
       total_reaction_time: socket.assigns.total_reaction_time + reaction_time,
       correct: updated[:correct] || socket.assigns.correct,
       wrong: updated[:wrong] || socket.assigns.wrong,
       phase: [],
       in_cycle: true,
       results: [%{result: result, reaction_time: reaction_time} | socket.assigns.results],
       timer_ref: ref,
       timer_start: System.monotonic_time(:millisecond)
     )}
  end

  defp save_final_result(socket) do
    task = Beam.Repo.get_by!(Beam.Exercices.Task, type: "searching_for_a_vowel")

    total = socket.assigns.correct + socket.assigns.wrong + socket.assigns.omitted
    accuracy = if total > 0, do: socket.assigns.correct / total, else: 0.0
    avg_time = if total > 0, do: socket.assigns.total_reaction_time / total, else: 0

    entry = %{
      user_id: socket.assigns.user_id,
      task_id: task.id,
      correct: socket.assigns.correct,
      wrong: socket.assigns.wrong,
      omitted: socket.assigns.omitted,
      accuracy: accuracy,
      reaction_time: avg_time
    }

    case Repo.insert(Result.changeset(%Result{}, entry)) do
      {:ok, r} -> {task.id, r.id}
      _ -> {task.id, nil}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 w-screen h-screen flex items-center justify-center bg-white">
      <%= if @current_user.type == "Terapeuta" do %>
        <button
          type="button"
          phx-click="toggle_pause"
          class={"absolute right-6 top-6 z-50 bg-yellow-100 border-2 border-yellow-400 rounded-full p-2 hover:bg-yellow-200 transition " <>
                (if not (@in_cycle or @preparing_task or @show_intro or @calculating_results), do: "", else: "opacity-40 pointer-events-none")}
          title={if @paused, do: "Retomar", else: "Pausar"}
          disabled={@in_cycle or @preparing_task or @show_intro or @calculating_results}
        >
          <.icon name={if @paused, do: "hero-play-mini", else: "hero-pause-mini"} class="w-8 h-8 text-yellow-700" />
        </button>
      <% end %>

      <%= unless @preparing_task or @show_intro do %>
        <div class="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-[40%] z-40">
          <div class="w-full h-6 bg-gray-300 rounded-full overflow-hidden shadow-inner">
            <div
              class="h-full bg-green-500 transition-all duration-300"
              style={
                if @calculating_results do
                  "width: 100%"
                else
                  "width: #{min(div((@current_phase_index - 1) * 100, @total_phases), 100)}%"
                end
              }
            ></div>
          </div>
          <div class="text-center mt-1 font-semibold text-gray-700">
            <%= if @calculating_results do %>
              <div class="mb-1 text-xl font-bold">A calcular resultados...</div>
              <div>Exercício Concluído</div>
            <% else %>
              <%= min(div((@current_phase_index - 1) * 100, @total_phases), 100) %>%
            <% end %>
          </div>
        </div>
      <% end %>

      <%= if @preparing_task do %>
        <div class="w-full h-full flex items-center justify-center bg-white">
          <p class="text-xl animate-pulse text-gray-700">A preparar tarefa...</p>
        </div>
      <% else %>
        <%= if @show_intro do %>
          <div class="flex flex-col items-center justify-center w-full h-full bg-white">
            <p class="text-2xl font-bold text-gray-800 mb-4">A vogal que tens de encontrar</p>
            <div class="w-32 h-32 flex items-center justify-center border-4 border-gray-600 rounded-full">
              <span class={"text-6xl font-bold #{tailwind_color(@target.color)}"}>
                <%= @target.vowel %>
              </span>
            </div>
          </div>
        <% else %>
          <div class="relative flex items-center justify-center w-full h-full bg-white">
            <div class="relative flex items-center justify-center w-[85vw] h-[85vh] border-[20px] border-gray-600">
              <%= for %{vowel: vowel, color: color, position: position} <- @phase do %>
                <button
                  phx-click="vowel_click"
                  phx-value-vowel={vowel}
                  phx-value-color={color}
                  class={"absolute #{position_to_class(position)} w-[7vw] h-[7vw] flex items-center justify-center bg-white border-4 border-gray-600 rounded-full #{tailwind_color(color)} text-3xl font-bold"}
                  disabled={@paused}
                >
                  <%= vowel %>
                </button>
              <% end %>
            </div>
          </div>
        <% end %>
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
    </div>
    """
  end

  defp position_to_class("up"), do: "-top-[50px] left-1/2 transform -translate-x-1/2"
  defp position_to_class("down"), do: "-bottom-[50px] left-1/2 transform -translate-x-1/2"
  defp position_to_class("left"), do: "top-1/2 -left-[50px] transform -translate-y-1/2"
  defp position_to_class("right"), do: "top-1/2 -right-[50px] transform -translate-y-1/2"

  defp tailwind_color("red"), do: "text-red-600"
  defp tailwind_color("blue"), do: "text-blue-600"
  defp tailwind_color("green"), do: "text-green-600"
  defp tailwind_color("yellow"), do: "text-yellow-300"
  defp tailwind_color(_), do: "text-gray-500"
end

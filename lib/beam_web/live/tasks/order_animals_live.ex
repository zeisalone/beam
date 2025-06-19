defmodule BeamWeb.Tasks.OrderAnimalsLive do
  use BeamWeb, :live_view
  alias Beam.Exercices.Tasks.OrderAnimals
  alias Beam.Exercices.Result
  alias Beam.Repo

  @slide_duration 400

  def mount(_params, session, socket) do
    current_user = session["current_user"]
    task_id = session["task_id"]
    live_action = session["live_action"] |> maybe_to_atom() || :training
    difficulty = session["difficulty"] |> maybe_to_atom() || :medio
    raw_config = session["config"] || %{}

    config =
      if is_map(raw_config) do
        Map.merge(OrderAnimals.default_config(), atomize_keys(raw_config))
      else
        OrderAnimals.default_config()
      end

    if connected?(socket), do: Process.send_after(self(), :start_round, 1000)

    {:ok,
     assign(socket,
       current_user: current_user,
       user_id: current_user.id,
       task_id: task_id,
       difficulty: difficulty,
       live_action: live_action,
       full_screen?: true,
       preparing: true,
       show_sequence: true,
       target_sequence: [],
       current_animal: nil,
       animating_out?: false,
       shuffled_options: [],
       user_sequence: [],
       dragging: nil,
       round_index: 0,
       correct: 0,
       wrong: 0,
       omitted: 0,
       full_sequence: 0,
       total_reaction_time: 0,
       current_start_time: nil,
       game_finished: false,
       config: config,
       paused: false,
       pause_info: nil,
       timers: %{}
     )}
  end

  def handle_info(:start_round, socket) do
    level_or_config =
      if socket.assigns.difficulty == :criado,
        do: socket.assigns.config,
        else: socket.assigns.difficulty

    %{target_sequence: seq, shuffled_options: opts} =
      OrderAnimals.generate_target_sequence(level_or_config)
      |> OrderAnimals.generate_phase()

    slide_timer = Process.send_after(self(), {:show_animal, 0}, 1000)

    {:noreply,
     assign(socket,
       preparing: false,
       show_sequence: true,
       target_sequence: seq,
       current_animal: nil,
       animating_out?: false,
       shuffled_options: opts,
       user_sequence: List.duplicate(nil, length(seq)),
       dragging: nil,
       timers: %{:slide => slide_timer}
     )}
  end

  def handle_info({:show_animal, idx}, socket) do
    if socket.assigns.paused do
      {:noreply, socket}
    else
      seq = socket.assigns.target_sequence
      if idx < length(seq) do
        animal = Enum.at(seq, idx)
        animal_time = socket.assigns.config.animal_total_time
        slide_out_delay = animal_time - @slide_duration

        out_timer = Process.send_after(self(), :animate_out, slide_out_delay)
        next_timer = Process.send_after(self(), {:show_animal, idx + 1}, animal_time)

        socket = assign(socket, current_animal: animal, animating_out?: false)
        {:noreply, assign(socket, timers: %{out: out_timer, next: next_timer})}
      else
        hide_timer = Process.send_after(self(), :hide_sequence, socket.assigns.config.animal_total_time)
        {:noreply, assign(socket, current_animal: nil, animating_out?: false, timers: %{hide: hide_timer})}
      end
    end
  end

  def handle_info(:animate_out, socket) do
    if socket.assigns.paused do
      {:noreply, socket}
    else
      {:noreply, assign(socket, animating_out?: true)}
    end
  end

  def handle_info(:hide_sequence, socket) do
    if socket.assigns.paused do
      {:noreply, socket}
    else
      {:noreply, assign(socket, show_sequence: false, current_start_time: System.monotonic_time())}
    end
  end

  def handle_info(:save_results, socket) do
    {task_id, result_id} = save_final_result(socket)

    case socket.assigns.live_action do
      :test -> Beam.Exercices.save_test_attempt(socket.assigns.user_id, task_id, result_id)
      :training -> Beam.Exercices.save_training_attempt(socket.assigns.user_id, task_id, result_id, socket.assigns.difficulty)
    end

    Process.sleep(3000)
    {:noreply, push_navigate(socket, to: ~p"/results/aftertask?task_id=#{task_id}")}
  end

  def handle_event("drop_animal", %{"slot" => slot_str, "animal" => animal, "displaced" => displaced}, socket) do
    idx = String.to_integer(slot_str)
    sequence = socket.assigns.user_sequence

    sequence =
      sequence
      |> Enum.map(fn x -> if x == animal, do: nil, else: x end)
      |> List.replace_at(idx, animal)
      |> then(fn seq ->
        if displaced && displaced != animal do
          case Enum.find_index(seq, &is_nil/1) do
            nil -> seq
            empty_idx -> List.replace_at(seq, empty_idx, displaced)
          end
        else
          seq
        end
      end)

    {:noreply, assign(socket, user_sequence: sequence)}
  end

  def handle_event("submit", %{"order" => user_order}, socket) do
    user_sequence =
      user_order
      |> Enum.sort_by(fn {k, _} -> String.to_integer(k) end)
      |> Enum.map(fn {_, v} -> v end)

    {correct, wrong, omitted} =
      OrderAnimals.evaluate_response(user_sequence, socket.assigns.target_sequence)

    was_full =
      Enum.all?(user_sequence, &(&1 in socket.assigns.target_sequence)) and
        OrderAnimals.validate_response(user_sequence, socket.assigns.target_sequence) == :correct

    full_sequence =
      if was_full, do: socket.assigns.full_sequence + 1, else: socket.assigns.full_sequence

    reaction_time = System.monotonic_time() - socket.assigns.current_start_time
    reaction_time_ms = System.convert_time_unit(reaction_time, :native, :millisecond)

    updated = %{
      correct: socket.assigns.correct + correct,
      wrong: socket.assigns.wrong + wrong,
      omitted: socket.assigns.omitted + omitted,
      full_sequence: full_sequence,
      total_reaction_time: socket.assigns.total_reaction_time + reaction_time_ms,
      round_index: socket.assigns.round_index + 1
    }

    total_rounds =
      if socket.assigns.difficulty == :criado,
        do: socket.assigns.config.total_rounds,
        else: 5

    if updated.round_index >= total_rounds do
      send(self(), :save_results)
      {:noreply, assign(socket, updated |> Map.put(:game_finished, true))}
    else
      next_timer = Process.send_after(self(), :start_round, 1000)
      {:noreply, assign(socket, updated |> Map.put(:timers, %{next: next_timer}))}
    end
  end

  def handle_event("toggle_pause", _params, socket) do
    paused = !socket.assigns.paused

    if paused do
      Enum.each(Map.values(socket.assigns.timers), fn ref ->
        if is_reference(ref), do: Process.cancel_timer(ref)
      end)

      {:noreply, assign(socket, paused: true, pause_info: nil, timers: %{})}
    else
      timers =
        cond do
          socket.assigns.preparing ->
            %{slide: Process.send_after(self(), :start_round, 1000)}
          socket.assigns.show_sequence && socket.assigns.current_animal && !socket.assigns.animating_out? ->
            animal_time = socket.assigns.config.animal_total_time
            slide_out_delay = animal_time - @slide_duration
            %{
              out: Process.send_after(self(), :animate_out, slide_out_delay),
              next: Process.send_after(self(), {:show_animal, find_current_animal_idx(socket)}, animal_time)
            }
          socket.assigns.show_sequence && is_nil(socket.assigns.current_animal) ->
            %{hide: Process.send_after(self(), :hide_sequence, socket.assigns.config.animal_total_time)}
          socket.assigns.game_finished ->
            %{}
          true ->
            %{}
        end

      {:noreply, assign(socket, paused: false, timers: timers)}
    end
  end

  defp find_current_animal_idx(socket) do
    Enum.find_index(socket.assigns.target_sequence, &(&1 == socket.assigns.current_animal)) || 0
  end

  defp save_final_result(socket) do
    task_id = socket.assigns.task_id
    total = socket.assigns.correct + socket.assigns.wrong + socket.assigns.omitted
    accuracy = if total > 0, do: socket.assigns.correct / total, else: 0.0
    avg_time = if total > 0, do: socket.assigns.total_reaction_time / total, else: 0

    result = %{
      user_id: socket.assigns.user_id,
      task_id: task_id,
      correct: socket.assigns.correct,
      wrong: socket.assigns.wrong,
      omitted: socket.assigns.omitted,
      accuracy: accuracy,
      reaction_time: avg_time,
      full_sequence: socket.assigns.full_sequence
    }

    case Repo.insert(Result.changeset(%Result{}, result)) do
      {:ok, r} -> {task_id, r.id}
      _ -> {task_id, nil}
    end
  end

  defp maybe_to_atom(nil), do: nil
  defp maybe_to_atom(val) when is_binary(val), do: String.to_existing_atom(val)
  defp maybe_to_atom(val), do: val

  defp atomize_keys(map) do
    for {k, v} <- map, into: %{} do
      key = if is_binary(k), do: String.to_existing_atom(k), else: k
      {key, v}
    end
  end

  defp animal_svg(animal) do
    path = Path.join(:code.priv_dir(:beam), "static/images/animals/#{animal}.svg")

    case File.read(path) do
      {:ok, svg} ->
        svg
        |> String.replace(~r/fill=["']#?[0-9a-fA-F]*["']/, "")
        |> String.replace(~r/id=["'][^"']*["']/, "")
        |> String.replace("<svg", ~s(<svg class="w-full h-full"))
      _ -> "<!-- SVG não encontrado -->"
    end
  end

  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-center h-screen bg-white">
      <%= if @current_user && @current_user.type == "Terapeuta" && !@game_finished do %>
        <button
          type="button"
          phx-click="toggle_pause"
          class={"absolute top-12 right-6 z-30 bg-yellow-100 border-2 border-yellow-400 rounded-full p-2 hover:bg-yellow-200 transition " <>
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

      <%= if @game_finished do %>
        <p class="text-xl font-bold text-gray-800">A calcular resultados...</p>
      <% else %>
        <%= if @preparing do %>
          <p class="text-xl font-bold text-gray-800 animate-pulse">A preparar exercício...</p>
        <% else %>
          <%= if @show_sequence do %>
            <div class="w-32 h-32 flex items-center justify-center">
              <%= if @current_animal do %>
                <div class={"w-full h-full #{if @animating_out?, do: "animate-slide-out", else: "animate-slide-in"}"}>
                  <%= raw(animal_svg(@current_animal)) %>
                </div>
              <% end %>
            </div>
          <% else %>
            <form phx-submit="submit">
              <div class="flex gap-2 mb-6">
                <%= for i <- 0..(length(@target_sequence) - 1) do %>
                  <div
                    id={"drop-slot-#{i}"}
                    class="w-24 h-24 border-2 border-dashed border-gray-400 bg-gray-50 flex items-center justify-center"
                    data-slot={i}
                    phx-hook="Drop"
                  >
                   <%= if animal = Enum.at(@user_sequence, i) do %>
                    <div
                      id={"user-sequence-animal-#{i}"}
                      class="w-full h-full"
                      draggable="true"
                      data-animal={animal}
                      phx-hook="Drag"
                    >
                      <%= raw(animal_svg(animal)) %>
                    </div>
                  <% end %>
                    <input type="hidden" name={"order[#{i}]"} value={Enum.at(@user_sequence, i) || ""} />
                  </div>
                <% end %>
              </div>

              <div class="flex flex-wrap gap-3 justify-center mb-4">
                <%= for animal <- @shuffled_options do %>
                  <div
                    id={"drag-animal-#{animal}"}
                    class="w-20 h-20 border cursor-move"
                    draggable="true"
                    data-animal={animal}
                    phx-hook="Drag"
                  >
                    <%= raw(animal_svg(animal)) %>
                  </div>
                <% end %>
              </div>

              <button type="submit" class="mt-4 px-6 py-2 bg-blue-600 text-white rounded">Enviar</button>
            </form>
          <% end %>
        <% end %>
      <% end %>
    </div>
    """
  end
end

defmodule BeamWeb.Tasks.FollowTheFigureLive do
  use BeamWeb, :live_view

  alias Beam.Exercices.Tasks.FollowTheFigure
  alias Beam.Exercices.Result
  alias Beam.Repo

  @default_config %{
    total_rounds: 20,
    initial_time: 15_000,
    gain_time: 4_000,
    penalty_time: 2_000
  }

  def mount(_params, session, socket) do
    current_user = Map.get(session, "current_user")
    task_id = Map.get(session, "task_id")
    live_action = Map.get(session, "live_action", "training") |> String.to_existing_atom()
    full_screen = Map.get(session, "full_screen?", true)
    raw_config = Map.get(session, "config", %{})

    difficulty =
      case live_action do
        :training -> Map.get(session, "difficulty", "medio") |> String.to_existing_atom()
        :test -> :medio
      end

    config = Map.merge(@default_config, if(is_map(raw_config), do: atomize_keys(raw_config), else: %{}))

    if connected?(socket), do: send(self(), :start_intro)

    {:ok,
     assign(socket,
       current_user: current_user,
       user_id: current_user.id,
       task_id: task_id,
       difficulty: difficulty,
       live_action: live_action,
       round: 1,
       time_left: config.initial_time,
       target: nil,
       distractors: [],
       clicked: false,
       round_start: nil,
       correct: 0,
       wrong: 0,
       omitted: 0,
       total_reaction_time: 0,
       results: [],
       show_intro: true,
       full_screen?: full_screen,
       last_feedback: nil,
       finished: false,
       config: config,
       paused: false,
       pause_info: nil,
       tick_ref: nil
     )}
  end

  def handle_info(:tick, socket) do
    if socket.assigns.paused do
      {:noreply, socket}
    else
      new_time = max(socket.assigns.time_left - 1000, 0)
      # Só reenvia timer se não chegou a 0
      tick_ref = if new_time > 0, do: Process.send_after(self(), :tick, 1000), else: nil
      if new_time == 0, do: send(self(), :timeout)
      {:noreply, assign(socket, time_left: new_time, tick_ref: tick_ref)}
    end
  end

  def handle_info(:start_intro, socket) do
    Process.send_after(self(), :start_round, 3000)
    {:noreply, socket}
  end

  def handle_info(:start_round, socket) do
    level_or_config =
      if socket.assigns.difficulty == :criado,
        do: socket.assigns.config,
        else: socket.assigns.difficulty

    round_data = FollowTheFigure.generate_round(socket.assigns.round, level_or_config)

    # Só inicia o timer no primeiro round (não recomeça a cada round)
    socket =
      if socket.assigns.round == 1 and not socket.assigns.paused do
        tick_ref = Process.send_after(self(), :tick, 1000)
        assign(socket, tick_ref: tick_ref)
      else
        socket
      end

    {:noreply,
     assign(socket,
       figures: round_data.figures,
       target: round_data.target,
       clicked: false,
       round_start: System.monotonic_time(),
       show_intro: false,
       last_feedback: nil
     )}
  end

  def handle_info(:timeout, socket) do
    omitted_remaining = max(socket.assigns.config.total_rounds - (socket.assigns.round - 1), 0)
    save_results(socket.assigns.correct, socket.assigns.wrong, socket.assigns.omitted + omitted_remaining, socket.assigns.total_reaction_time, socket)
  end

  def handle_event("select", %{"shape" => shape, "color" => color}, socket) do
    if socket.assigns.paused or socket.assigns.clicked do
      {:noreply, socket}
    else
      reaction_time = System.monotonic_time() - socket.assigns.round_start |> System.convert_time_unit(:native, :millisecond)
      result = FollowTheFigure.validate_selection(%{shape: shape, color: color}, socket.assigns.target)

      socket = assign(socket, clicked: true, last_feedback: result)
      advance_round(result, reaction_time, socket)
    end
  end

  def handle_event("toggle_pause", _params, socket) do
    paused = !socket.assigns.paused

    if paused do
      # Cancela timer do tick se existir
      if is_reference(socket.assigns.tick_ref), do: Process.cancel_timer(socket.assigns.tick_ref)
      {:noreply, assign(socket, paused: true, pause_info: %{time_left: socket.assigns.time_left}, tick_ref: nil)}
    else
      # Só volta a contar se não terminou
      tick_ref = if socket.assigns.time_left > 0, do: Process.send_after(self(), :tick, 1000), else: nil
      {:noreply, assign(socket, paused: false, pause_info: nil, tick_ref: tick_ref)}
    end
  end

  defp advance_round(result, reaction_time, socket) do
    %{gain_time: gain, penalty_time: penalty, total_rounds: total_rounds} = socket.assigns.config

    updates =
      case result do
        :correct -> %{correct: socket.assigns.correct + 1, time_left: socket.assigns.time_left + gain}
        :wrong -> %{wrong: socket.assigns.wrong + 1, time_left: max(socket.assigns.time_left - penalty, 0)}
      end

    new_results = [%{result: result, time: reaction_time} | socket.assigns.results]
    round = socket.assigns.round + 1

    if round > total_rounds do
      if is_reference(socket.assigns.tick_ref), do: Process.cancel_timer(socket.assigns.tick_ref)
      save_results(
        updates[:correct] || socket.assigns.correct,
        updates[:wrong] || socket.assigns.wrong,
        socket.assigns.omitted,
        socket.assigns.total_reaction_time + reaction_time,
        socket
      )
    else
      Process.send_after(self(), :start_round, 500)

      {:noreply,
       assign(socket,
         round: round,
         total_reaction_time: socket.assigns.total_reaction_time + reaction_time,
         results: new_results
       ) |> assign(updates)}
    end
  end

  defp save_results(correct, wrong, omitted, total_reaction_time, socket) do
    total = socket.assigns.config.total_rounds
    accuracy = correct / total
    avg_reaction_time = if correct > 0, do: total_reaction_time / correct, else: 0

    result_entry = %{
      user_id: socket.assigns.user_id,
      task_id: socket.assigns.task_id,
      correct: correct,
      wrong: wrong,
      omitted: omitted,
      accuracy: accuracy,
      reaction_time: avg_reaction_time
    }

    changeset = Result.changeset(%Result{}, result_entry)

    case Repo.insert(changeset) do
      {:ok, result} ->
        case socket.assigns.live_action do
          :test -> Beam.Exercices.save_test_attempt(socket.assigns.user_id, socket.assigns.task_id, result.id)
          :training -> Beam.Exercices.save_training_attempt(socket.assigns.user_id, socket.assigns.task_id, result.id, socket.assigns.difficulty)
        end
        {:noreply, push_navigate(socket, to: ~p"/results/aftertask?task_id=#{socket.assigns.task_id}")}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Erro ao salvar resultado.")}
    end
  end

  defp atomize_keys(map) do
    for {k, v} <- map, into: %{} do
      key = if is_binary(k), do: String.to_existing_atom(k), else: k
      {key, v}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 w-screen h-screen flex overflow-hidden">
      <div class="flex-1 relative bg-black overflow-hidden">
        <%= if @target do %>
          <%= if @show_intro do %>
            <div class="flex flex-col items-center justify-center w-full h-full text-white">
              <p class="text-2xl font-bold mb-4">A forma que tens de seguir</p>
              <div class="w-24 h-24">
                <%= raw(shape_svg(@target.shape, @target.color)) %>
              </div>
              <p class="text-lg mt-4">
                Forma:
                <span class={"#{tailwind_color(@target.color)} font-semibold"}>
                  <%= @target.shape %>
                </span>
              </p>
            </div>
          <% else %>
            <div class="absolute inset-0">
              <%= for {shape_map, index} <- Enum.with_index(@figures) do %>
                <% shape = shape_map.shape %>
                <% color = shape_map.color %>
                <% layout = Map.get(shape_map, :layout, :random) %>
                <% top = if layout == :center_block, do: 30 + div(index, 3) * 12, else: :rand.uniform(90) %>
                <% left = if layout == :center_block, do: 30 + rem(index, 3) * 12, else: :rand.uniform(85) %>

                <div
                  class={"absolute animate-floating animate-delay-#{rem(index * 2, 10)}s"}
                  style={"top: #{top}%; left: #{left}%; width: 64px; height: 64px;"}
                >
                  <%= raw(shape_svg(shape, color)) %>
                </div>
              <% end %>
            </div>

            <%= if @clicked do %>
              <div class="absolute bottom-8 left-1/2 transform -translate-x-1/2 text-white font-semibold text-lg">
                A processar resposta...
              </div>
            <% end %>
          <% end %>
        <% else %>
          <div class="w-full h-full flex items-center justify-center text-white">
            <p class="text-xl animate-pulse">A preparar tarefa...</p>
          </div>
        <% end %>
      </div>

      <div class="w-60 bg-white border-l border-gray-300 p-4 flex flex-col justify-start items-center z-50 mb-2 relative">
        <%= if @current_user && @current_user.type == "Terapeuta" do %>
          <button
            type="button"
            phx-click="toggle_pause"
            class={"absolute left-3 top-3 z-40 bg-yellow-100 border-2 border-yellow-400 rounded-full p-2 hover:bg-yellow-200 transition shadow " <>
                    (if @paused, do: "ring-2 ring-yellow-200", else: "")}
            title={if @paused, do: "Retomar", else: "Pausar"}
            style="outline:none;"
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="w-7 h-7 text-yellow-700" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <%= if @paused do %>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3" />
              <% else %>
                <rect x="6" y="5" width="4" height="14" rx="1"/><rect x="14" y="5" width="4" height="14" rx="1"/>
              <% end %>
            </svg>
          </button>
        <% end %>

        <%= if @paused do %>
          <div class="absolute inset-0 z-50 bg-black bg-opacity-50 flex flex-col justify-center items-center rounded-xl">
            <button
              phx-click="toggle_pause"
              class="flex flex-col items-center group focus:outline-none"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="w-20 h-20 mb-2 text-yellow-400 group-hover:text-yellow-300 transition" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2" fill="none"/>
                <polygon points="10,8 16,12 10,16" fill="currentColor"/>
              </svg>
              <span class="text-2xl font-black text-yellow-200 group-hover:text-yellow-100">Retomar</span>
            </button>
            <span class="mt-2 text-white text-base">Clique no botão acima para continuar</span>
          </div>
        <% end %>

        <p class="text-sm text-gray-600 font-medium mb-1 mt-3">Alvo:</p>
        <div class="w-24 h-24 border-4 border-yellow-400 rounded-xl mb-4 flex items-center justify-center">
          <div class="w-16 h-16">
            <%= if @target do %>
              <%= raw(shape_svg(@target.shape, @target.color)) %>
            <% end %>
          </div>
        </div>

        <div class="text-center mt-5 relative h-24 flex flex-col items-center justify-center">
          <p class="text-gray-600 text-sm mb-1">Tempo</p>
          <p class="text-5xl font-extrabold text-black"><%= div(@time_left, 1000) %>s</p>

          <%= if @last_feedback do %>
            <div class={
              "absolute top-full mt-1 text-lg font-semibold transition-all duration-300 " <>
              case @last_feedback do
                :correct -> "text-green-400 animate-fade-down"
                :wrong -> "text-red-400 animate-fade-down"
              end
            }>
              <%= if @last_feedback == :correct do %>
                +<%= round(@config.gain_time / 1000) %>
              <% else %>
                -<%= round(@config.penalty_time / 1000) %>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp shape_svg(shape, color, attrs \\ %{})

  defp shape_svg(nil, _, _), do: ""
  defp shape_svg(_, nil, _), do: ""

  defp shape_svg(shape, color, attrs) do
    file_path = Path.join(:code.priv_dir(:beam), "static/images/#{shape}.svg")

    case File.read(file_path) do
      {:ok, svg_content} ->
        attr_str =
          Enum.map(attrs, fn {k, v} -> "#{k}=\"#{v}\"" end)
          |> Enum.join(" ")

        svg_content
        |> String.replace(~r/fill=["']#?[0-9a-fA-F]*["']/, "")
        |> String.replace(~r/class=["'].*?["']/, "")
        |> String.replace(
          "<svg",
          "<svg #{attr_str} class=\"w-16 h-16 fill-current #{tailwind_color(color)}\" style=\"pointer-events: none;\""
        )
        |> String.replace(
          ~r/<(path|polygon|circle|rect|ellipse|line|polyline)([^>]*)>/,
          "<\\1\\2 pointer-events=\"auto\" phx-click=\"select\" phx-value-shape=\"#{shape}\" phx-value-color=\"#{color}\" />"
        )

      {:error, _} -> "<!-- SVG not found -->"
    end
  end

  defp tailwind_color("red"), do: "text-red-600"
  defp tailwind_color("blue"), do: "text-blue-500"
  defp tailwind_color("green"), do: "text-green-500"
  defp tailwind_color("yellow"), do: "text-yellow-400"
  defp tailwind_color("purple"), do: "text-purple-500"
  defp tailwind_color("orange"), do: "text-orange-400"
  defp tailwind_color(_), do: "text-gray-500"
end

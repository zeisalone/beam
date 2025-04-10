defmodule BeamWeb.Tasks.FollowTheFigureLive do
  use BeamWeb, :live_view

  alias Beam.Exercices.Tasks.FollowTheFigure
  alias Beam.Exercices.Result
  alias Beam.Repo

  @total_rounds 20
  @initial_time 15_000
  @gain_time 4_000
  @penalty_time 2_000

  def mount(_params, session, socket) do
    current_user = Map.get(session, "current_user")
    task_id = Map.get(session, "task_id")
    live_action = Map.get(session, "live_action", "training") |> String.to_existing_atom()
    full_screen = Map.get(session, "full_screen?", true)
    difficulty =
      case live_action do
        :training ->
          Map.get(session, "difficulty", "medio") |> String.to_existing_atom()

        :test ->
          :medio
      end


    if connected?(socket) do
      send(self(), :start_intro)
    end

    {:ok,
     assign(socket,
       user_id: current_user.id,
       task_id: task_id,
       difficulty: difficulty,
       live_action: live_action,
       round: 1,
       time_left: @initial_time,
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
       finished: false
     )}
  end

  def handle_info(:tick, socket) do
    new_time = max(socket.assigns.time_left - 1000, 0)

    if new_time == 0 do
      send(self(), :timeout)
    else
      Process.send_after(self(), :tick, 1000)
    end

    {:noreply, assign(socket, time_left: new_time)}
  end

  def handle_info(:start_intro, socket) do
    Process.send_after(self(), :start_round, 3000)
    {:noreply, socket}
  end

  def handle_info(:start_round, socket) do
    round_data = FollowTheFigure.generate_round(socket.assigns.round, socket.assigns.difficulty)

    if socket.assigns.round == 1 do
      Process.send_after(self(), :tick, 1000)
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
    current_round = socket.assigns.round
    omitted_remaining = max(@total_rounds - (current_round - 1), 0)

    save_results(
      socket.assigns.correct,
      socket.assigns.wrong,
      socket.assigns.omitted + omitted_remaining,
      socket.assigns.total_reaction_time,
      socket
    )
  end

  def handle_event("select", %{"shape" => shape, "color" => color}, socket) do
    reaction_time = System.monotonic_time() - socket.assigns.round_start |> System.convert_time_unit(:native, :millisecond)
    result = FollowTheFigure.validate_selection(%{shape: shape, color: color}, socket.assigns.target)

    socket =
      assign(socket,
        clicked: true,
        last_feedback: result
      )

    advance_round(result, reaction_time, socket)
  end

  defp advance_round(result, reaction_time, socket) do
    updates =
      case result do
        :correct -> %{correct: socket.assigns.correct + 1, time_left: socket.assigns.time_left + @gain_time}
        :wrong -> %{wrong: socket.assigns.wrong + 1, time_left: max(socket.assigns.time_left - @penalty_time, 0)}
      end

    new_results = [%{result: result, time: reaction_time} | socket.assigns.results]
    round = socket.assigns.round + 1

    cond do
      round > @total_rounds ->
        save_results(
          updates[:correct] || socket.assigns.correct,
          updates[:wrong] || socket.assigns.wrong,
          socket.assigns.omitted,
          socket.assigns.total_reaction_time,
          socket
        )

      true ->
        Process.send_after(self(), :start_round, 500)

        {:noreply,
         assign(socket,
           round: round,
           total_reaction_time: socket.assigns.total_reaction_time + reaction_time,
           results: new_results
         )
         |> assign(updates)}
    end
  end

  defp save_results(correct, wrong, omitted, total_reaction_time, socket) do
    accuracy = correct / @total_rounds
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
          :test ->
            Beam.Exercices.save_test_attempt(socket.assigns.user_id, socket.assigns.task_id, result.id)

          :training ->
            Beam.Exercices.save_training_attempt(
              socket.assigns.user_id,
              socket.assigns.task_id,
              result.id,
              socket.assigns.difficulty
            )
        end

        {:noreply, push_navigate(socket, to: ~p"/results/aftertask?task_id=#{socket.assigns.task_id}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Erro ao salvar resultado.")}
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

                <button
                  phx-click="select"
                  phx-value-shape={shape}
                  phx-value-color={color}
                  class={"w-16 h-16 hover:scale-110 transition-transform animate-floating animate-delay-#{rem(index * 2, 10)}s " <>
                        if layout == :center_block, do: "absolute", else: "absolute"}
                  style={
                    if layout == :center_block do
                      top = 30 + div(index, 3) * 12
                      left = 30 + rem(index, 3) * 12
                      "top: #{top}%; left: #{left}%;"
                    else
                      "top: #{:rand.uniform(90)}%; left: #{:rand.uniform(85)}%;"
                    end
                  }
                >
                  <div class="w-full h-full pointer-events-none">
                    <%= raw(shape_svg(shape, color)) %>
                  </div>
                </button>
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

      <div class="w-60 bg-white border-l border-gray-300 p-4 flex flex-col justify-start items-center z-50 mb-2">
        <p class="text-sm text-gray-600 font-medium mb-1">Alvo:</p>
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
              <%= if @last_feedback == :correct, do: "+4", else: "-2" %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp shape_svg(nil, _), do: ""
  defp shape_svg(_, nil), do: ""

  defp shape_svg(shape, color) do
    file_path = Path.join(:code.priv_dir(:beam), "static/images/#{shape}.svg")

    case File.read(file_path) do
      {:ok, svg_content} ->
        svg_content
        |> String.replace(~r/fill=["']#?[0-9a-fA-F]*["']/, "")
        |> String.replace(
          "<svg",
          "<svg class=\"w-full h-full fill-current #{tailwind_color(color)} pointer-events-none\""
        )
        |> String.replace(
          ~r/<path(.*?)>/,
          "<path\\1 pointer-events=\"auto\">"
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

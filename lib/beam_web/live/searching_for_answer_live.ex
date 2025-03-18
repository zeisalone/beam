defmodule BeamWeb.SearchingForAnAnswerLive do
  use BeamWeb, :live_view
  alias Beam.Exercices.SearchingForAnAnswer
  alias Beam.Repo
  alias Beam.Exercices.Result

  @default_target %{shape: "heart", color: "red", position: "up"}
  @phase_duration 3000
  @cycle_duration 2000
  @total_phases 20

  def mount(_params, session, socket) do
    current_user = Map.get(session, "current_user", nil)

    task_id = Map.get(session, "task_id", nil)
    live_action = Map.get(session, "live_action", "training") |> maybe_to_atom()
    difficulty = Map.get(session, "difficulty") |> maybe_to_atom() || :facil

    if current_user do
      if connected?(socket), do: Process.send_after(self(), :start_phase, 0)

      target = @default_target

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
         difficulty: difficulty
       )}
    else
      {:ok, push_navigate(socket, to: "/tasks")}
    end
  end

  defp maybe_to_atom(nil), do: nil
  defp maybe_to_atom(value) when is_binary(value), do: String.to_existing_atom(value)
  defp maybe_to_atom(value), do: value

  def handle_info(:start_phase, socket) do
    phase = SearchingForAnAnswer.generate_phase(socket.assigns.target, socket.assigns.difficulty)

    Process.send_after(self(), :start_cycle, @phase_duration)

    {:noreply,
     assign(socket,
       phase: phase,
       current_phase_start: System.monotonic_time(),
       in_cycle: false
     )}
  end

  def handle_info(:start_cycle, socket) do
    Process.send_after(self(), :next_phase, @cycle_duration)

    {:noreply,
     assign(socket,
       phase: [],
       in_cycle: true
     )}
  end

  def handle_info(:next_phase, socket) do
    was_omitted = socket.assigns.user_response == nil
    reaction_time = if was_omitted, do: @phase_duration, else: 0

    if socket.assigns.current_phase_index >= @total_phases do
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
    if socket.assigns.in_cycle do
      {:noreply, socket}
    else
      key_to_position = %{
        "ArrowUp" => "up",
        "ArrowDown" => "down",
        "ArrowLeft" => "left",
        "ArrowRight" => "right"
      }

      user_position = Map.get(key_to_position, key, nil)

      if user_position do
        reaction_time =
          (System.monotonic_time() - socket.assigns.current_phase_start)
          |> System.convert_time_unit(:native, :millisecond)

        target =
          Enum.find(
            socket.assigns.phase,
            &(&1.shape == socket.assigns.target.shape && &1.color == socket.assigns.target.color)
          )

        result =
          cond do
            reaction_time > @phase_duration -> :omitted
            user_position == target.position -> :correct
            true -> :wrong
          end

        update_counts =
          case result do
            :correct -> %{correct: socket.assigns.correct + 1}
            :wrong -> %{wrong: socket.assigns.wrong + 1}
            :omitted -> %{omitted: socket.assigns.omitted + 1}
          end

        new_results = [%{result: result, reaction_time: reaction_time} | socket.assigns.results]

        {:noreply,
         assign(socket,
           user_response: user_position,
           total_reaction_time: socket.assigns.total_reaction_time + reaction_time,
           omitted: update_counts[:omitted] || socket.assigns.omitted,
           correct: update_counts[:correct] || socket.assigns.correct,
           wrong: update_counts[:wrong] || socket.assigns.wrong,
           phase: [],
           in_cycle: true,
           results: new_results
         )}
      else
        {:noreply, socket}
      end
    end
  end

  defp save_final_result(socket) do
    task_id = Beam.Exercices.TaskList.task_id(:searching_for_an_answer)
    total_attempts = socket.assigns.correct + socket.assigns.wrong + socket.assigns.omitted
    accuracy = if total_attempts > 0, do: socket.assigns.correct / total_attempts, else: 0.0

    avg_reaction_time =
      if total_attempts > 0, do: socket.assigns.total_reaction_time / total_attempts, else: 0

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

  def render(assigns) do
    ~H"""
    <div
      class="fixed inset-0 w-screen h-screen flex items-center justify-center bg-white"
      phx-window-keydown="key_pressed"
      phx-capture-keydown
    >
      <%= if @calculating_results do %>
        <p class="text-2xl font-bold text-gray-800">A calcular resultados...</p>
      <% else %>
        <div class="relative flex items-center justify-center w-full h-full bg-white">
          <div class="relative flex items-center justify-center w-[85vw] h-[85vh] border-[20px] border-gray-600">
            <%= for %{position: position, shape: shape, color: color} <- @phase do %>
              <div class={"absolute #{position_to_class(position)} w-[7vw] h-[7vw] flex items-center justify-center #{tailwind_color(color)} rounded-full bg-white border-4 border-gray-600"}>
                <div class="w-[75%] h-[75%] flex items-center justify-center">
                  {raw(shape_svg(shape, color))}
                </div>
              </div>
            <% end %>
          </div>
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

  defp shape_svg(shape, color) do
    file_path = Path.join(:code.priv_dir(:beam), "static/images/#{shape}.svg")

    case File.read(file_path) do
      {:ok, svg_content} ->
        svg_content
        |> String.replace(~r/fill=["']#?[0-9a-fA-F]*["']/, "")
        |> String.replace(
          "<svg",
          "<svg class=\"w-full h-full fill-current #{tailwind_color(color)}\""
        )

      {:error, _reason} ->
        "<!-- SVG não encontrado -->"
    end
  end
end

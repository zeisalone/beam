defmodule BeamWeb.Tasks.CodeOfSymbolsLive do
  use BeamWeb, :live_view

  alias Beam.Exercices.Tasks.CodeOfSymbols
  alias Beam.Repo
  alias Beam.Exercices.Result

  @default_timeouts %{facil: 45_000, medio: 45_000, dificil: 45_000, default: 45_000}

  def mount(_params, session, socket) do
    current_user = Map.get(session, "current_user")
    task_id = Map.get(session, "task_id")
    live_action = Map.get(session, "live_action", "training") |> maybe_to_atom()
    difficulty = Map.get(session, "difficulty") |> maybe_to_atom() || :medio
    full_screen = Map.get(session, "full_screen?", true)

    raw_config = Map.get(session, "config", %{})

    config =
      Map.merge(CodeOfSymbols.default_config(),
        if(is_map(raw_config), do: atomize_keys(raw_config), else: %{})
      )

    response_timeout =
      Map.get(config, :response_timeout, Map.get(@default_timeouts, difficulty, @default_timeouts.default))

    if current_user do
      code = CodeOfSymbols.generate_code(difficulty, config)
      grid = CodeOfSymbols.generate_grid(code, difficulty, config)

      socket =
        assign(socket,
          current_user: current_user,
          user_id: current_user.id,
          task_id: task_id,
          code: code,
          grid: grid,
          user_input: %{},
          correct: 0,
          wrong: 0,
          omitted: 0,
          start_time: nil,
          total_reaction_time: 0,
          live_action: live_action,
          difficulty: difficulty,
          show_code: true,
          game_started: false,
          game_finished: false,
          loading: true,
          full_screen?: full_screen,
          timeout_ref: nil,
          response_timeout: response_timeout
        )

      if connected?(socket), do: Process.send_after(self(), :hide_loading, 1000)
      {:ok, socket}
    else
      {:ok, push_navigate(socket, to: "/tarefas")}
    end
  end

  def handle_event("start_task", _params, socket) do
    timeout_ref = Process.send_after(self(), :timeout, socket.assigns.response_timeout)

    {:noreply,
     assign(socket,
       game_started: true,
       show_code: false,
       start_time: System.monotonic_time(),
       timeout_ref: timeout_ref
     )}
  end

  def handle_event("update_input", %{"input" => input_map}, socket) do
    updated_input =
      input_map
      |> Enum.filter(fn {k, _v} -> Regex.match?(~r/^\d+$/, k) end)
      |> Enum.map(fn {k, v} -> {String.to_integer(k), parse_int(v)} end)
      |> Enum.into(%{})

    {:noreply, assign(socket, user_input: updated_input)}
  end

  def handle_event("submit", _params, socket) do
    if socket.assigns.timeout_ref, do: Process.cancel_timer(socket.assigns.timeout_ref)
    process_result(socket)
  end

  def handle_info(:hide_loading, socket) do
    {:noreply, assign(socket, loading: false)}
  end

  def handle_info(:finish_redirect, socket) do
    {:noreply, push_navigate(socket, to: ~p"/results/aftertask?task_id=#{socket.assigns.task_id}")}
  end

  def handle_info(:timeout, socket), do: process_result(socket)

  defp process_result(socket) do
    {correct, wrong, omitted} =
      CodeOfSymbols.evaluate_responses(socket.assigns.grid, build_user_input_list(socket))

    reaction_time =
      System.monotonic_time() - (socket.assigns.start_time || System.monotonic_time())

    reaction_time_ms = System.convert_time_unit(reaction_time, :native, :millisecond)

    result_entry =
      CodeOfSymbols.create_result_entry(
        socket.assigns.user_id,
        socket.assigns.task_id,
        correct,
        wrong,
        omitted,
        reaction_time_ms
      )

    case Repo.insert(Result.changeset(%Result{}, result_entry)) do
      {:ok, result} ->
        save_attempt(socket, result.id)
        Process.send_after(self(), :finish_redirect, 2000)
        {:noreply, assign(socket, game_finished: true)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao salvar resultado")}
    end
  end

  defp build_user_input_list(socket) do
    total = length(socket.assigns.grid)

    Enum.map(0..(total - 1), fn i ->
      Map.get(socket.assigns.user_input, i, nil)
    end)
  end

  defp grid_columns_class(grid_cell_count) do
    cols =
      grid_cell_count
      |> :math.sqrt()
      |> Float.round()
      |> trunc()

    "grid grid-cols-#{cols} gap-4"
  end


  defp save_attempt(socket, result_id) do
    case socket.assigns.live_action do
      :test ->
        Beam.Exercices.save_test_attempt(
          socket.assigns.user_id,
          socket.assigns.task_id,
          result_id
        )

      :training ->
        Beam.Exercices.save_training_attempt(
          socket.assigns.user_id,
          socket.assigns.task_id,
          result_id,
          socket.assigns.difficulty
        )

      _ ->
        :ok
    end
  end

  defp parse_int(str) do
    case Integer.parse(str) do
      {int, _} -> int
      _ -> nil
    end
  end

  defp atomize_keys(map) do
    for {k, v} <- map, into: %{} do
      key = if is_binary(k), do: String.to_existing_atom(k), else: k
      {key, v}
    end
  end

  defp maybe_to_atom(nil), do: nil
  defp maybe_to_atom(value) when is_binary(value), do: String.to_existing_atom(value)
  defp maybe_to_atom(value), do: value

  defp tailwind_color("red"), do: "text-red-600"
  defp tailwind_color("blue"), do: "text-blue-600"
  defp tailwind_color("green"), do: "text-green-600"
  defp tailwind_color("yellow"), do: "text-yellow-300"
  defp tailwind_color("purple"), do: "text-purple-500"
  defp tailwind_color("orange"), do: "text-orange-500"
  defp tailwind_color("teal"), do: "text-teal-500"
  defp tailwind_color("pink"), do: "text-pink-400"
  defp tailwind_color(_), do: "text-gray-400"

  defp render_svg(shape, color) do
    file_path = Path.join(:code.priv_dir(:beam), "static/images/#{shape}.svg")

    case File.read(file_path) do
      {:ok, svg_content} ->
        svg_content
        |> String.replace(~r/fill=["']#?[0-9a-fA-F]*["']/, "")
        |> String.replace("<svg", "<svg class=\"w-full h-full fill-current #{tailwind_color(color)}\"")

      {:error, _} ->
        "<!-- SVG não encontrado -->"
    end
  end

  def render(assigns) do
    ~H"""
    <div class="p-4 max-w-6xl mx-auto">
      <%= if @loading do %>
        <div class="items-center text-center justify-center text-2xl font-bold text-gray-800">
          A preparar tarefa...
        </div>
      <% else %>
        <%= if @game_finished do %>
          <div class="items-center text-center justify-center text-2xl font-bold text-gray-800">
            A calcular resultados...
          </div>
        <% else %>
          <%= if @show_code do %>
            <div class="text-center">
              <h2 class="text-xl font-bold mb-4 text-gray-700">Código</h2>
              <div class="flex justify-center flex-wrap gap-8 mb-8">
                <%= for %{shape: shape, color: color, digit: digit} <- @code do %>
                  <div class="flex flex-col items-center text-center w-20">
                    <div class="w-14 h-14"><%= raw(render_svg(shape, color)) %></div>
                    <div class="text-lg font-bold mt-2"><%= digit %></div>
                  </div>
                <% end %>
              </div>
              <button phx-click="start_task" class="px-5 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition text-sm">
                Iniciar
              </button>
            </div>

          <% else %>
            <form phx-submit="submit" phx-change="update_input" class="mt-6">
              <% grid_class = grid_columns_class(length(@grid)) %>
                <div class={grid_class}>
                <%= for {%{shape: shape, color: color}, index} <- Enum.with_index(@grid) do %>
                  <div class="flex flex-col items-center text-center">
                    <div class="w-8 h-8"><%= raw(render_svg(shape, color)) %></div>
                    <input
                      type="text"
                      name={"input[#{index}]"}
                      class="mt-1 w-9 h-9 text-center border border-gray-300 rounded-md text-sm leading-tight"
                      maxlength="1"
                      pattern="[0-9]"
                      value={Map.get(@user_input, index, "")}
                    />
                  </div>
                <% end %>
              </div>

              <div class="text-center mt-4">
                <button type="submit" class="px-5 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 transition text-sm">
                  Enviar
                </button>
              </div>
            </form>
          <% end %>
        <% end %>
      <% end %>
    </div>
    """
  end
end

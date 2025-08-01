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
      Map.merge(CodeOfSymbols.default_config(),
        if(is_map(raw_config), do: atomize_keys(raw_config), else: %{})
      )

    response_timeout =
      Map.get(config, :response_timeout, Map.get(@default_timeouts, difficulty, @default_timeouts.default))

    if current_user do
      chosen_difficulty =
        if is_nil(difficulty) do
          CodeOfSymbols.choose_level_by_age(current_user.id)
        else
          difficulty
        end

      code = CodeOfSymbols.generate_code(chosen_difficulty, config)
      grid = CodeOfSymbols.generate_grid(code, chosen_difficulty, config)

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
          difficulty: chosen_difficulty,
          show_code: true,
          game_started: false,
          game_finished: false,
          loading: true,
          full_screen?: full_screen,
          timeout_ref: nil,
          timer_ref: nil,
          response_timeout: response_timeout,
          paused: false,
          pause_info: nil,
          time_left: response_timeout
        )

      if connected?(socket), do: Process.send_after(self(), :hide_loading, 1000)
      {:ok, socket}
    else
      {:ok, push_navigate(socket, to: "/tarefas")}
    end
  end

  def handle_event("start_task", _params, socket) do
    {:ok, timer_ref} = :timer.send_interval(1000, self(), :tick)
    timeout_ref = Process.send_after(self(), :timeout, socket.assigns.response_timeout)

    {:noreply,
     assign(socket,
       game_started: true,
       show_code: false,
       start_time: System.monotonic_time(),
       timeout_ref: timeout_ref,
       timer_ref: timer_ref,
       paused: false,
       pause_info: nil,
       time_left: socket.assigns.response_timeout
     )}
  end

  def handle_event("toggle_pause", _params, socket) do
    can_pause =
      socket.assigns.current_user.type == "Terapeuta" and
      socket.assigns.game_started and
      not socket.assigns.show_code and
      not socket.assigns.game_finished

    if can_pause do
      paused = !socket.assigns.paused
      if paused do
        if socket.assigns.timer_ref, do: :timer.cancel(socket.assigns.timer_ref)
        if socket.assigns.timeout_ref, do: Process.cancel_timer(socket.assigns.timeout_ref)
        {:noreply, assign(socket, paused: true, pause_info: %{time_left: socket.assigns.time_left}, timer_ref: nil, timeout_ref: nil)}
      else
        %{time_left: time_left} = socket.assigns.pause_info
        {:ok, timer_ref} = :timer.send_interval(1000, self(), :tick)
        timeout_ref = Process.send_after(self(), :timeout, max(time_left, 1))
        {:noreply,
          assign(socket,
            paused: false,
            pause_info: nil,
            timer_ref: timer_ref,
            timeout_ref: timeout_ref,
            time_left: time_left
          )
        }
      end
    else
      {:noreply, socket}
    end
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
    if socket.assigns.timer_ref, do: :timer.cancel(socket.assigns.timer_ref)
    process_result(socket)
  end

  def handle_info(:hide_loading, socket) do
    {:noreply, assign(socket, loading: false)}
  end

  def handle_info(:finish_redirect, socket) do
    {:noreply, push_navigate(socket, to: ~p"/results/aftertask?task_id=#{socket.assigns.task_id}")}
  end

  def handle_info(:timeout, socket) do
    if socket.assigns.paused do
      {:noreply, socket}
    else
      if socket.assigns.timer_ref, do: :timer.cancel(socket.assigns.timer_ref)
      process_result(socket)
    end
  end

  def handle_info(:tick, socket) do
    if socket.assigns.paused or socket.assigns.game_finished do
      {:noreply, socket}
    else
      new_time = socket.assigns.time_left - 1000
      if new_time <= 0 do
        send(self(), :timeout)
        {:noreply, assign(socket, time_left: 0)}
      else
        {:noreply, assign(socket, time_left: new_time)}
      end
    end
  end

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

  defp grid_class(size) do
    case size do
      16 -> "grid grid-cols-4 gap-4"
      25 -> "grid grid-cols-5 gap-4"
      36 -> "grid grid-cols-6 gap-3"
      49 -> "grid grid-cols-7 gap-3"
      64 -> "grid grid-cols-8 gap-2"
      _  -> "grid grid-cols-4 gap-4"
    end
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
            <div class="absolute top-2 right-4 text-lg text-gray-500 font-bold">
              <%= div(@time_left, 1000) %>s
            </div>
            <%= if @current_user.type == "Terapeuta" do %>
              <button
                type="button"
                phx-click="toggle_pause"
                class="absolute right-6 top-6 z-50 bg-yellow-100 border-2 border-yellow-400 rounded-full p-2 hover:bg-yellow-200 transition"
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

            <form phx-submit="submit" phx-change="update_input" class="mt-6">
              <div class={grid_class(length(@grid))}>
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
                      disabled={@paused}
                    />
                  </div>
                <% end %>
              </div>
              <div class="text-center mt-4">
                <button type="submit" class="px-5 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 transition text-sm" disabled={@paused}>
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

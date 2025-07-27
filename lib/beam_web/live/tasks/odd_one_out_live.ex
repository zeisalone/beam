defmodule BeamWeb.Tasks.OddOneOutLive do
  use BeamWeb, :live_view

  alias Beam.Exercices.Tasks.OddOneOut
  alias Beam.Repo
  alias Beam.Exercices.Result

  @impl true
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
      Map.merge(OddOneOut.default_config(),
        if(is_map(raw_config), do: atomize_keys(raw_config), else: %{})
      )

    if current_user do
      chosen_difficulty =
        if is_nil(difficulty) do
          :medio # (ou podes criar a lógica choose_level_by_age se quiseres)
        else
          difficulty
        end

      state = OddOneOut.initial_state(chosen_difficulty, config)
      grid_info = OddOneOut.generate_grid(state)

      socket =
        assign(socket,
          current_user: current_user,
          user_id: current_user.id,
          task_id: task_id,
          live_action: live_action,
          difficulty: chosen_difficulty,
          full_screen?: full_screen,
          config: config,
          state: state,
          grid_info: grid_info,
          round: 1,
          game_started: false,
          game_finished: false,
          loading: true,
          results: [],
          reaction_times: [],
          start_time: nil
        )

      if connected?(socket), do: Process.send_after(self(), :hide_loading, 1000)
      {:ok, socket}
    else
      {:ok, push_navigate(socket, to: "/tarefas")}
    end
  end

  @impl true
  def handle_event("start_task", _params, socket) do
    {:noreply,
      assign(socket,
        game_started: true,
        loading: false,
        round: 1,
        start_time: now_ms()
      )
    }
  end

  @impl true
  def handle_event("pick_cell", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    %{state: state, grid_info: grid_info, results: results, reaction_times: reaction_times, start_time: start_time} = socket.assigns

    correct? = (index == grid_info.odd_index)
    new_results = results ++ [if(correct?, do: 1, else: 0)]
    reaction_time = now_ms() - (start_time || now_ms())
    new_reaction_times = reaction_times ++ [reaction_time]

    finished? = state.round >= state.total_rounds

    # Próxima ronda
    new_state =
      if !finished? do
        OddOneOut.next_round(%{state | results: new_results}, correct?)
      else
        %{state | results: new_results}
      end

    socket =
      socket
      |> assign(
        results: new_results,
        reaction_times: new_reaction_times,
        state: new_state,
        round: state.round + 1,
        game_finished: finished?,
        start_time: now_ms()
      )
      |> update_grid(new_state, finished?)

    if finished? do
      save_result_and_redirect(socket)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("omit_round", _params, socket) do
    %{state: state, results: results, reaction_times: reaction_times, start_time: start_time} = socket.assigns

    new_results = results ++ [:omitted]
    reaction_time = now_ms() - (start_time || now_ms())
    new_reaction_times = reaction_times ++ [reaction_time]

    finished? = state.round >= state.total_rounds

    new_state =
      if !finished? do
        OddOneOut.next_round(%{state | results: new_results}, false)
      else
        %{state | results: new_results}
      end

    socket =
      socket
      |> assign(
        results: new_results,
        reaction_times: new_reaction_times,
        state: new_state,
        round: state.round + 1,
        game_finished: finished?,
        start_time: now_ms()
      )
      |> update_grid(new_state, finished?)

    if finished? do
      save_result_and_redirect(socket)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:hide_loading, socket) do
    {:noreply, assign(socket, loading: false)}
  end

  @impl true
  def handle_info(:finish_redirect, socket) do
    {:noreply, push_navigate(socket, to: ~p"/results/aftertask?task_id=#{socket.assigns.task_id}")}
  end

  defp update_grid(socket, _state, true), do: assign(socket, grid_info: nil)
  defp update_grid(socket, state, false), do: assign(socket, grid_info: OddOneOut.generate_grid(state))

  defp save_result_and_redirect(socket) do
    correct = Enum.count(socket.assigns.results, &(&1 == 1))
    wrong = Enum.count(socket.assigns.results, &(&1 == 0))
    omitted = Enum.count(socket.assigns.results, &(&1 == :omitted))
    avg_reaction_time =
      if socket.assigns.reaction_times == [], do: 0,
      else: Enum.sum(socket.assigns.reaction_times) |> div(length(socket.assigns.reaction_times))

    result_entry = %{
      user_id: socket.assigns.user_id,
      task_id: socket.assigns.task_id,
      correct: correct,
      wrong: wrong,
      omitted: omitted,
      accuracy: OddOneOut.calculate_accuracy(correct, wrong, omitted),
      reaction_time: avg_reaction_time
    }

    case Repo.insert(Result.changeset(%Result{}, result_entry)) do
      {:ok, result} ->
        save_attempt(socket, result.id)
        Process.send_after(self(), :finish_redirect, 2000)
        {:noreply, assign(socket, game_finished: true)}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao salvar resultado")}
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
      _ -> :ok
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

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp grid_class(size) do
    cond do
      size == 9 -> "grid grid-cols-3 gap-1"
      size == 16 -> "grid grid-cols-4 gap-1"
      size == 25 -> "grid grid-cols-5 gap-1"
      size == 36 -> "grid grid-cols-6 gap-1"
      size == 49 -> "grid grid-cols-7 gap-1"
      size == 64 -> "grid grid-cols-8 gap-1"
      size == 81 -> "grid grid-cols-9 gap-1"
      true -> "grid grid-cols-4 gap-1"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 max-w-4xl mx-auto">
      <%= if @loading do %>
        <div class="items-center text-center justify-center text-2xl font-bold text-gray-800">
          A preparar tarefa...
        </div>
      <% else %>
        <%= if !@game_started do %>
          <div class="text-center my-16">
            <h2 class="text-2xl font-bold mb-4 text-gray-700">"O diferente"</h2>
            <p class="mb-6">Encontra o elemento diferente em cada grelha. A grelha cresce ou diminui conforme o teu desempenho.<br/>Clica para começar.</p>
            <button phx-click="start_task" class="px-6 py-3 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition text-lg">
              Iniciar
            </button>
          </div>
        <% else %>
          <%= if @game_finished do %>
            <div class="items-center text-center justify-center text-2xl font-bold text-gray-800 my-20">
              A calcular resultados...
            </div>
          <% else %>
            <div class="flex flex-row items-center justify-between mb-2 max-w-xl mx-auto">
              <span class="font-bold text-base text-gray-600">Ronda <%= @state.round %> / <%= @state.total_rounds %></span>
              <span class="font-bold text-base text-gray-600">Acertos: <%= Enum.count(@results, &(&1 == 1)) %></span>
            </div>
            <div class="flex flex-col items-center mt-10">
              <div class={grid_class(length(@grid_info.grid))}>
                <%= for {val, idx} <- Enum.with_index(@grid_info.grid) do %>
                  <button
                    type="button"
                    class="w-12 h-12 text-2xl md:text-2xl font-bold focus:outline-none bg-transparent transition-all select-none"
                    phx-click="pick_cell"
                    phx-value-index={idx}
                    disabled={@game_finished}
                    style="letter-spacing:0.02em;"
                  ><%= val %></button>
                <% end %>
              </div>
            </div>
            <div class="mt-6 flex justify-center">
              <button
                type="button"
                phx-click="omit_round"
                class="text-base text-blue-600 hover:underline hover:text-blue-800 px-4 py-2 bg-transparent font-semibold"
                disabled={@game_finished}
              >
                Desisto / Seguir em frente
              </button>
            </div>
          <% end %>
        <% end %>
      <% end %>
    </div>
    """
  end
end

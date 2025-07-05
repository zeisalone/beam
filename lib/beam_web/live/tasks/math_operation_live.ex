defmodule BeamWeb.Tasks.MathOperationLive do
  use BeamWeb, :live_view
  alias Beam.Exercices.Tasks.MathOperation
  alias Beam.Repo
  alias Beam.Exercices.Result

  @total_questions 10
  @initial_pause 1000

  @impl true
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
        MathOperation.default_config(),
        case raw_config do
          map when is_map(map) -> atomize_keys(map)
          _ -> %{}
        end
      )

    equation_display_time = Map.get(config, :equation_display_time, 2000)
    answer_time_limit = Map.get(config, :answer_time_limit, 4000)

    if current_user do
      questions =
        if is_nil(difficulty) do
          build_questions(nil, config, current_user)
        else
          build_questions(difficulty, config)
        end

      {first_a, first_b, first_operator, first_result, first_options} = Enum.at(questions, 0)

      if connected?(socket), do: Process.send_after(self(), :show_equation, @initial_pause)

      {:ok,
        assign(socket,
          current_user: current_user,
          user_id: current_user.id,
          task_id: task_id,
          questions: questions,
          current_question_index: 0,
          correct: 0,
          wrong: 0,
          omitted: 0,
          total_reaction_time: 0,
          live_action: live_action,
          difficulty: difficulty,
          total_questions: @total_questions,
          a: first_a,
          b: first_b,
          operator: first_operator,
          result: first_result,
          options: first_options,
          full_screen?: full_screen,
          phase: :waiting,
          start_time: nil,
          equation_display_time: equation_display_time,
          answer_time_limit: answer_time_limit,
          timer_ref: nil,
          paused: false,
          pause_info: nil,
          time_left: nil,
          tick_ref: nil
        )}
    else
      {:ok, push_navigate(socket, to: "/users/log_in")}
    end
  end

  defp build_questions(:criado, config),
    do: (for _ <- 1..@total_questions, do: MathOperation.generate_question(:criado, config))

  defp build_questions(level, _config),
    do: (for _ <- 1..@total_questions, do: MathOperation.generate_question(level))

  defp build_questions(_level, _config, current_user) do
    for _ <- 1..@total_questions, do: MathOperation.generate_question(current_user)
  end

  defp atomize_keys(map) do
    for {k, v} <- map, into: %{} do
      key = if is_binary(k), do: String.to_existing_atom(k), else: k
      {key, v}
    end
  end

  defp maybe_to_atom(nil), do: nil
  defp maybe_to_atom(value) when is_binary(value), do: String.to_existing_atom(value)
  defp maybe_to_atom(_), do: nil
  defp cancel_if_ref(timer_ref) when is_reference(timer_ref), do: Process.cancel_timer(timer_ref)
  defp cancel_if_ref(_), do: :ok

  @impl true
  def handle_info(:show_equation, socket) do
    if socket.assigns.paused do
      {:noreply, socket}
    else
      if socket.assigns.phase == :waiting do
        cancel_if_ref(socket.assigns.timer_ref)
        ref = Process.send_after(self(), :show_options, socket.assigns.equation_display_time)
        {:noreply, assign(socket, phase: :show_equation, timer_ref: ref, timer_start: System.system_time(:millisecond))}
      else
        {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_info(:show_options, socket) do
    if socket.assigns.paused do
      {:noreply, socket}
    else
      if socket.assigns.phase == :show_equation do
        cancel_if_ref(socket.assigns.timer_ref)
        if is_reference(socket.assigns.tick_ref), do: Process.cancel_timer(socket.assigns.tick_ref)
        ref = Process.send_after(self(), :timeout, socket.assigns.answer_time_limit)
        tick_ref = Process.send_after(self(), :tick, 1000)
        {:noreply,
          assign(socket,
            phase: :show_options,
            start_time: System.system_time(:millisecond),
            timer_ref: ref,
            timer_start: System.system_time(:millisecond),
            time_left: socket.assigns.answer_time_limit,
            tick_ref: tick_ref
          )}
      else
        {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_info(:tick, socket) do
    if socket.assigns.paused or socket.assigns.phase != :show_options do
      if is_reference(socket.assigns.tick_ref), do: Process.cancel_timer(socket.assigns.tick_ref)
      {:noreply, assign(socket, tick_ref: nil)}
    else
      new_time = max(socket.assigns.time_left - 1000, 0)
      tick_ref = if new_time > 0, do: Process.send_after(self(), :tick, 1000), else: nil
      {:noreply, assign(socket, time_left: new_time, tick_ref: tick_ref)}
    end
  end

  @impl true
  def handle_info(:timeout, socket) do
    if socket.assigns.paused do
      {:noreply, socket}
    else
      if socket.assigns.phase == :show_options do
        if is_reference(socket.assigns.tick_ref), do: Process.cancel_timer(socket.assigns.tick_ref)
        handle_omission(socket)
      else
        {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("toggle_pause", _params, socket) do
    phase = socket.assigns.phase
    if phase in [:show_equation, :show_options] do
      paused = !socket.assigns.paused
      if paused do
        time_passed = System.system_time(:millisecond) - (socket.assigns.timer_start || System.system_time(:millisecond))
        time_left =
          cond do
            phase == :show_equation -> max(socket.assigns.equation_display_time - time_passed, 1)
            phase == :show_options -> max(socket.assigns.time_left, 1)
            true -> nil
          end

        cancel_if_ref(socket.assigns.timer_ref)
        if is_reference(socket.assigns.tick_ref), do: Process.cancel_timer(socket.assigns.tick_ref)
        {:noreply, assign(socket, paused: true, pause_info: %{phase: phase, time_left: time_left}, timer_ref: nil, tick_ref: nil)}
      else
        %{phase: paused_phase, time_left: time_left} = socket.assigns.pause_info || %{phase: nil, time_left: nil}

        {_next_msg, ref, tick_ref} =
          case paused_phase do
            :show_equation -> {:show_options, Process.send_after(self(), :show_options, time_left), nil}
            :show_options ->
              {
                :timeout,
                Process.send_after(self(), :timeout, time_left),
                if(time_left > 0, do: Process.send_after(self(), :tick, 1000), else: nil)
              }
            _ -> {nil, nil, nil}
          end

        {:noreply,
          assign(socket,
            paused: false,
            pause_info: nil,
            timer_ref: ref,
            tick_ref: tick_ref,
            timer_start: System.system_time(:millisecond)
          )
        }
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("submit_answer", %{"answer" => answer}, socket) do
    if socket.assigns.paused do
      {:noreply, socket}
    else
      if socket.assigns.phase == :show_options do
        cancel_if_ref(socket.assigns.timer_ref)
        if is_reference(socket.assigns.tick_ref), do: Process.cancel_timer(socket.assigns.tick_ref)

        reaction_time = System.system_time(:millisecond) - socket.assigns.start_time
        user_answer = String.to_integer(answer)

        current_index = socket.assigns.current_question_index
        total_questions = socket.assigns.total_questions

        {_a, _b, _operator, correct_answer, _options} = Enum.at(socket.assigns.questions, current_index)

        is_correct = MathOperation.validate_answer(user_answer, correct_answer)
        correct = if is_correct, do: socket.assigns.correct + 1, else: socket.assigns.correct
        wrong = if is_correct, do: socket.assigns.wrong, else: socket.assigns.wrong + 1
        total_reaction_time = socket.assigns.total_reaction_time + reaction_time

        if current_index + 1 >= total_questions do
          save_results(correct, wrong, socket.assigns.omitted, total_reaction_time, socket)
        else
          next_question(socket, correct: correct, wrong: wrong, total_reaction_time: total_reaction_time)
        end
      else
        {:noreply, socket}
      end
    end
  end

  defp handle_omission(socket) do
    cancel_if_ref(socket.assigns.timer_ref)
    if is_reference(socket.assigns.tick_ref), do: Process.cancel_timer(socket.assigns.tick_ref)
    current_index = socket.assigns.current_question_index
    total_questions = socket.assigns.total_questions
    total_reaction_time = socket.assigns.total_reaction_time + socket.assigns.answer_time_limit

    if current_index + 1 >= total_questions do
      save_results(socket.assigns.correct, socket.assigns.wrong, socket.assigns.omitted + 1, total_reaction_time, socket)
    else
      next_question(socket, omitted: socket.assigns.omitted + 1, total_reaction_time: total_reaction_time)
    end
  end

  defp next_question(socket, updates) do
    cancel_if_ref(socket.assigns.timer_ref)
    if is_reference(socket.assigns.tick_ref), do: Process.cancel_timer(socket.assigns.tick_ref)

    current_index = socket.assigns.current_question_index + 1
    {new_a, new_b, new_operator, new_result, new_options} =
      Enum.at(socket.assigns.questions, current_index)

    ref = Process.send_after(self(), :show_equation, @initial_pause)

    {:noreply,
      assign(socket,
        current_question_index: current_index,
        a: new_a,
        b: new_b,
        operator: new_operator,
        result: new_result,
        options: new_options,
        phase: :waiting,
        start_time: nil,
        timer_ref: ref,
        timer_start: System.system_time(:millisecond),
        time_left: nil,
        tick_ref: nil
      )
      |> assign(updates)}
  end

  defp save_results(correct, wrong, omitted, total_reaction_time, socket) do
    avg_reaction_time =
      if correct + wrong + omitted > 0,
        do: total_reaction_time / (correct + wrong + omitted),
        else: 0

    result_entry = MathOperation.create_result_entry(
      socket.assigns.user_id,
      socket.assigns.task_id,
      correct,
      wrong,
      omitted,
      avg_reaction_time
    )

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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative min-h-screen flex flex-col justify-center items-center pt-10 pb-24">
      <%= if @phase == :show_options do %>
        <div class="absolute top-2 right-4 text-lg text-gray-500 font-bold">
          <%= div(@time_left, 1000) %>s
        </div>
      <% end %>

      <%= if @current_user.type == "Terapeuta" do %>
        <button
          type="button"
          phx-click="toggle_pause"
          class={"absolute right-6 top-8 z-30 bg-yellow-100 border-2 border-yellow-400 rounded-full p-2 hover:bg-yellow-200 transition " <>
                (if @phase in [:show_equation, :show_options], do: "", else: "opacity-40 pointer-events-none")}
          title={if @paused, do: "Retomar", else: "Pausar"}
          disabled={not (@phase in [:show_equation, :show_options])}
        >
          <.icon name={if @paused, do: "hero-play-mini", else: "hero-pause-mini"} class="w-8 h-8 text-yellow-700" />
        </button>
      <% end %>

      <%= if @paused do %>
        <div class="fixed inset-0 z-40 bg-black bg-opacity-70 flex flex-col justify-center items-center">
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
      <h1 class="text-3xl font-bold mb-6">Resolve a Operação Matemática</h1>

      <%= if @phase == :show_equation do %>
        <div class="p-6 rounded-lg shadow-md w-full max-w-md text-center">
          <p class="text-6xl font-bold">
            <%= @a %> <%= @operator %> <%= @b %>
          </p>
        </div>
      <% end %>

      <%= if @phase == :show_options do %>
        <div class="mt-8 flex justify-center space-x-4 flex-wrap max-w-xl">
          <%= for option <- @options do %>
            <button
              class="bg-gray-500 text-white text-2xl font-bold px-10 py-4 rounded-lg shadow-md hover:bg-gray-700 transition-all"
              type="button"
              phx-click="submit_answer"
              phx-value-answer={option}
              disabled={@paused}
            >
              <%= option %>
            </button>
          <% end %>
        </div>
      <% end %>

      <div class="fixed bottom-6 left-0 right-0 flex justify-center space-x-2">
        <%= for i <- 1..@total_questions do %>
          <div class={
            "w-6 h-6 rounded-full border-2 text-xs font-bold flex items-center justify-center transition-all duration-200 " <>
            if i <= @current_question_index, do: "bg-green-500 text-white", else: "bg-gray-300 text-gray-400"
          }>
            <%= i %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end

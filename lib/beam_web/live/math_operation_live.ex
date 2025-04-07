defmodule BeamWeb.MathOperationLive do
  use BeamWeb, :live_view
  alias Beam.Exercices.MathOperation
  alias Beam.Repo
  alias Beam.Exercices.Result

  @total_questions 20
  @initial_pause 1000
  @equation_display_time 2000
  @answer_time_limit 4000

  @impl true
  def mount(_params, session, socket) do
    current_user = Map.get(session, "current_user", nil)

    task_id = Map.get(session, "task_id", nil)
    live_action = Map.get(session, "live_action", "training") |> maybe_to_atom()
    difficulty = Map.get(session, "difficulty", "medio") |> maybe_to_atom()
    full_screen = Map.get(session, "full_screen?", true)

    if current_user do
      questions = for _ <- 1..@total_questions, do: MathOperation.generate_question(difficulty)

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
         start_time: nil
       )}
    else
      {:ok, push_navigate(socket, to: "/users/log_in")}
    end
  end

  @impl true
  def handle_info(:show_equation, socket) do
    Process.send_after(self(), :show_options, @equation_display_time)

    {:noreply, assign(socket, phase: :show_equation)}
  end

  @impl true
  def handle_info(:show_options, socket) do
    Process.send_after(self(), :timeout, @answer_time_limit)

    {:noreply,
     assign(socket,
       phase: :show_options,
       start_time: System.system_time(:millisecond)
     )}
  end

  @impl true
  def handle_info(:timeout, socket) do
    if socket.assigns.phase == :show_options do
      handle_omission(socket)
    else
      {:noreply, socket}
    end
  end

  defp handle_omission(socket) do
    current_index = socket.assigns.current_question_index
    total_questions = socket.assigns.total_questions
    total_reaction_time = socket.assigns.total_reaction_time + @answer_time_limit

    if current_index + 1 >= total_questions do
      save_results(socket.assigns.correct, socket.assigns.wrong, socket.assigns.omitted + 1, total_reaction_time, socket)
    else
      next_question(socket, omitted: socket.assigns.omitted + 1, total_reaction_time: total_reaction_time)
    end
  end

  @impl true
  def handle_event("submit_answer", %{"answer" => answer}, socket) do
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
  end

  defp next_question(socket, updates) do
    current_index = socket.assigns.current_question_index + 1
    {new_a, new_b, new_operator, new_result, new_options} =
      Enum.at(socket.assigns.questions, current_index)

    Process.send_after(self(), :show_equation, @equation_display_time)

    {:noreply,
     assign(socket,
       current_question_index: current_index,
       a: new_a,
       b: new_b,
       operator: new_operator,
       result: new_result,
       options: new_options,
       phase: :waiting,
       start_time: nil
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

  defp maybe_to_atom(nil), do: nil
  defp maybe_to_atom(value) when is_binary(value), do: String.to_existing_atom(value)
  defp maybe_to_atom(_), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center mt-10">
      <h1 class="text-3xl font-bold">Resolva a Operação Matemática</h1>
      <p class="text-lg mt-4">
        Questão <span class="font-semibold"><%= @current_question_index + 1 %></span>
        de <span class="font-semibold"><%= @total_questions %></span>
      </p>

      <%= if @phase == :show_equation do %>
        <div class="mt-6 p-6 rounded-lg shadow-md w-full text-center">
          <p class="text-6xl font-bold">
            <%= @a %> <%= @operator %> <%= @b %>
          </p>
        </div>
      <% end %>

      <%= if @phase == :show_options do %>
        <div class="mt-10 flex justify-center space-x-4 w-full">
          <%= for option <- @options do %>
            <button
              class="bg-gray-500 text-white text-2xl font-bold px-10 py-4 rounded-lg shadow-md hover:bg-gray-700 transition-all"
              type="button"
              phx-click="submit_answer"
              phx-value-answer={option}
            >
              <%= option %>
            </button>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end

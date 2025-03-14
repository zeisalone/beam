defmodule BeamWeb.MathOperationLive do
  use BeamWeb, :live_view
  alias Beam.Exercices.MathOperation
  alias Beam.Repo
  alias Beam.Exercices.Result

  def mount(_params, _session, socket) do
    {a, b, result, options} = MathOperation.generate_question()
    user_id = socket.assigns.current_user.id

    {:ok, assign(socket, a: a, b: b, result: result, options: options, user_id: user_id)}
  end

  def render(assigns) do
    ~H"""
    <.header>Solve the Math Problem</.header>
    <p>What is {@a} + {@b}?</p>

    <div class=" max-w-2xl grid grid-cols-2 gap-4 mt-4">
      <%= for option <- @options do %>
        <button
          class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-700"
          type="button"
          phx-click="submit_answer"
          phx-value-answer={option}
          phx-value-start_time={System.system_time(:millisecond)}
        >
          {option}
        </button>
      <% end %>
    </div>
    """
  end

  def handle_event("submit_answer", %{"answer" => answer, "start_time" => start_time}, socket) do
    reaction_time = System.system_time(:millisecond) - String.to_integer(start_time)
    user_answer = String.to_integer(answer)
    correct_answer = socket.assigns.result
    user_id = socket.assigns.user_id
    task_id = Beam.Exercices.TaskList.task_id(:math_operation)

    is_correct = MathOperation.validate_answer(user_answer, correct_answer)
    correct = if is_correct, do: 1, else: 0
    wrong = if is_correct, do: 0, else: 1

    result_entry = %{
      user_id: user_id,
      task_id: task_id,
      correct: correct,
      wrong: wrong,
      omitted: 0,
      reaction_time: reaction_time,
      accuracy: correct / (correct + wrong)
    }

    changeset = Result.changeset(%Result{}, result_entry)

    case Repo.insert(changeset) do
      {:ok, _} ->
        {:noreply, push_navigate(socket, to: ~p"/results/aftertask?task_id=#{task_id}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Error saving the result.")}
    end
  end
end

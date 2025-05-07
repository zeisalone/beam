defmodule BeamWeb.Results.ResultsEndLive do
  use BeamWeb, :live_view
  alias Beam.Repo
  alias Beam.Exercices.Result
  alias Beam.Exercices
  import Ecto.Query

  def mount(%{"task_id" => task_id}, _session, socket) do
    user_id = socket.assigns.current_user.id
    task = Exercices.get_task!(task_id)

    latest_result = fetch_latest_result(user_id, task.id)

    {:ok, assign(socket, results: [latest_result], full_screen?: false, task_name: task.name)}
  end

  defp fetch_latest_result(user_id, task_id) do
    Repo.one(
      from r in Result,
        where: r.user_id == ^user_id and r.task_id == ^task_id,
        order_by: [desc: r.inserted_at],
        limit: 1,
        select: %{
          correct: coalesce(r.correct, 0),
          wrong: coalesce(r.wrong, 0),
          omitted: coalesce(r.omitted, 0),
          accuracy: coalesce(r.accuracy, 0.0),
          reaction_time: coalesce(r.reaction_time, 0)
        }
    )
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col items-center bg-white px-4 pt-16">
      <h1 class="text-xl font-semibold text-gray-800 mb-6">
        Resultados da Tarefa: <%= @task_name %>
      </h1>

      <%= for result <- @results do %>
        <div class="text-center mb-6">
          <p class="text-5xl font-extrabold text-gray-900">
            <%= result.correct %>/<%= result.correct + result.wrong + result.omitted %>
          </p>
          <p class="text-xl text-gray-600 mt-2">
            <%= Float.round(result.accuracy * 100, 2) %>%
          </p>
        </div>

        <details class="w-full max-w-md bg-gray-100 rounded shadow-md p-4 text-left">
          <summary class="cursor-pointer font-medium text-gray-700">Ver em detalhe</summary>
          <div class="mt-4 text-sm text-gray-700 space-y-2">
            <p><strong>Respostas Corretas:</strong> <%= result.correct %></p>
            <p><strong>Respostas Erradas:</strong> <%= result.wrong %></p>
            <p><strong>Respostas Omitidas:</strong> <%= result.omitted %></p>
            <p><strong>Precisão:</strong> <%= Float.round(result.accuracy * 100, 2) %>%</p>
            <p><strong>Tempo Médio de Reação:</strong> <%= Float.round(result.reaction_time / 1000, 2) %>s</p>
          </div>
        </details>
      <% end %>

      <div class="mt-8 flex flex-col sm:flex-row gap-4">
        <.link navigate={~p"/results"} class="px-4 py-2 bg-blue-500 text-white rounded text-center">
          Ver todos os Resultados
        </.link>
        <.link navigate={~p"/tasks"} class="px-4 py-2 bg-gray-500 text-white rounded text-center">
          Voltar às Tarefas
        </.link>
      </div>
    </div>
    """
  end
end

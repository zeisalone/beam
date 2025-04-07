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
    <div class="p-10 text-center">
      <h1 class="text-3xl font-bold mb-6">Resultados da Tarefa: {@task_name}</h1>

      <table class="table-auto border-collapse border border-gray-300 w-full mt-4">
        <thead>
          <tr class="bg-gray-200">
            <th class="border border-gray-300 px-4 py-2">Corretos</th>
            <th class="border border-gray-300 px-4 py-2">Errados</th>
            <th class="border border-gray-300 px-4 py-2">Omitidos</th>
            <th class="border border-gray-300 px-4 py-2">Precisão (%)</th>
            <th class="border border-gray-300 px-4 py-2">Tempo de Reação Médio (s)</th>
          </tr>
        </thead>
        <tbody>
          <%= for result <- @results do %>
            <tr class="hover:bg-gray-100">
              <td class="border border-gray-300 px-4 py-2 text-center">{result.correct}</td>
              <td class="border border-gray-300 px-4 py-2 text-center">{result.wrong}</td>
              <td class="border border-gray-300 px-4 py-2 text-center">{result.omitted || 0}</td>
              <td class="border border-gray-300 px-4 py-2 text-center">
                {Float.round(result.accuracy * 100, 2)}%
              </td>
              <td class="border border-gray-300 px-4 py-2 text-center">
                {Float.round(result.reaction_time / 1000, 2)}s
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>

      <div class="mt-6">
        <.link navigate={~p"/results"} class="px-4 py-2 bg-blue-500 text-white rounded">
          Ver todos os Resultados
        </.link>
        <.link navigate={~p"/tasks"} class="px-4 py-2 bg-blue-500 text-white rounded">
          Voltar às tarefas
        </.link>
      </div>
    </div>
    """
  end
end

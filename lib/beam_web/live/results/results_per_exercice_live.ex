defmodule BeamWeb.Results.ResultsPerExerciseLive do
  use BeamWeb, :live_view
  alias Beam.Exercices

  def mount(params, _session, socket) do
    task_id = params["task_id"]
    task_name = Exercices.get_task_name(task_id)
    users = list_users_with_results(task_id)
    results = if task_id, do: Exercices.list_task_results(task_id), else: []

    {:ok,
     assign(socket,
       results: results,
       all_results: results,
       task_id: task_id,
       task_name: task_name,
       users: users,
       selected_user_id: nil,
       selected_result_type: nil,
       sort_order: :desc
     )}
  end

  def handle_event("filter_user", %{"user_id" => user_id}, socket) do
    user_id = if user_id == "", do: nil, else: String.to_integer(user_id)

    filtered_results =
      socket.assigns.all_results
      |> filter_by_user(user_id)
      |> filter_by_result_type(socket.assigns.selected_result_type)

    {:noreply, assign(socket, results: filtered_results, selected_user_id: user_id)}
  end

  def handle_event("filter_result_type", %{"result_type" => result_type}, socket) do
    selected_result_type = if result_type == "", do: nil, else: result_type

    filtered_results =
      socket.assigns.all_results
      |> filter_by_user(socket.assigns.selected_user_id)
      |> filter_by_result_type(selected_result_type)

    {:noreply,
     assign(socket, results: filtered_results, selected_result_type: selected_result_type)}
  end

  def handle_event("toggle_sort", _params, socket) do
    new_sort_order = if socket.assigns.sort_order == :asc, do: :desc, else: :asc

    sorted_results =
      Enum.sort_by(socket.assigns.results, & &1.inserted_at, fn a, b ->
        case new_sort_order do
          :asc -> NaiveDateTime.compare(a, b) == :lt
          :desc -> NaiveDateTime.compare(a, b) == :gt
        end
      end)

    {:noreply, assign(socket, results: sorted_results, sort_order: new_sort_order)}
  end

  defp filter_by_user(results, nil), do: results
  defp filter_by_user(results, user_id), do: Enum.filter(results, &(&1.user_id == user_id))

  defp filter_by_result_type(results, nil), do: results

  defp filter_by_result_type(results, "Teste"),
    do: Enum.filter(results, &(&1.result_type == "Teste"))

  defp filter_by_result_type(results, "Treino"),
    do: Enum.filter(results, &String.starts_with?(&1.result_type, "Treino"))

  defp format_date(datetime) do
    datetime
    |> NaiveDateTime.to_date()
    |> Calendar.strftime("%d/%m/%Y")
  end

  defp list_users_with_results(task_id) do
    results = Exercices.list_task_results(task_id)
    user_ids = Enum.uniq(Enum.map(results, & &1.user_id))

    user_ids
    |> Enum.map(fn user_id ->
      case Beam.Repo.get(Beam.Accounts.User, user_id) do
        %{type: "Paciente"} = user -> %{id: user.id, name: user.name}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  def render(assigns) do
    ~H"""
    <div class="p-10">
      <h1 class="text-3xl font-bold mb-6">Resultados da Tarefa: {@task_name}</h1>

      <div class="flex flex-wrap items-end justify-between gap-6 mb-6">
        <div class="flex gap-4">
          <div class="bg-purple-100 text-purple-800 px-6 py-4 rounded shadow min-w-[180px]">
            <div class="text-sm font-semibold">Média de Precisão</div>
            <div class="text-2xl font-bold">
              <%= if Enum.any?(@results) do %>
                <%= Float.round(Enum.reduce(@results, 0, fn r, acc -> acc + r.accuracy end) / length(@results) * 100, 1) %>%
              <% else %>
                N/A
              <% end %>
            </div>
          </div>

          <div class="bg-blue-100 text-blue-800 px-6 py-4 rounded shadow min-w-[180px]">
            <div class="text-sm font-semibold">Média de Tempo de Reação</div>
            <div class="text-2xl font-bold">
              <%= if Enum.any?(@results) do %>
                <%= Float.round(Enum.reduce(@results, 0, fn r, acc -> acc + r.reaction_time end) / length(@results) / 1000, 2) %>s
              <% else %>
                N/A
              <% end %>
            </div>
          </div>
        </div>

        <div class="flex gap-4 flex-wrap items-end">
          <form phx-change="filter_user">
            <label for="user_filter" class="block text-sm font-medium text-gray-700 mb-1">
              Filtrar por Utilizador:
            </label>
            <select name="user_id" id="user_filter" class="p-2 border rounded w-60">
              <option value="">Todos os Pacientes</option>
              <%= for user <- @users do %>
                <option value={user.id} selected={@selected_user_id == user.id}>
                  <%= user.name %>
                </option>
              <% end %>
            </select>
          </form>

          <form phx-change="filter_result_type">
            <label for="result_type_filter" class="block text-sm font-medium text-gray-700 mb-1">
              Filtrar por Tipo:
            </label>
            <select name="result_type" id="result_type_filter" class="p-2 border rounded w-40">
              <option value="">Todos</option>
              <option value="Teste" selected={@selected_result_type == "Teste"}>Testes</option>
              <option value="Treino" selected={@selected_result_type == "Treino"}>Treinos</option>
            </select>
          </form>
        </div>
      </div>

      <%= if @results == [] do %>
        <p class="text-center text-gray-500">Nenhum resultado encontrado.</p>
      <% else %>
        <table class="w-full border-collapse border border-gray-300">
          <thead>
            <tr class="bg-gray-200">
              <th class="border border-gray-300 px-4 py-2">Paciente</th>
              <th class="border border-gray-300 px-4 py-2">Tipo</th>
              <th class="border border-gray-300 px-4 py-2">Corretas</th>
              <th class="border border-gray-300 px-4 py-2">Erradas</th>
              <th class="border border-gray-300 px-4 py-2">Omitidas</th>
              <th class="border border-gray-300 px-4 py-2">Precisão</th>
              <th class="border border-gray-300 px-4 py-2">Tempo de Reação</th>
              <th class="border border-gray-300 px-4 py-2 cursor-pointer" phx-click="toggle_sort">
                Data {if @sort_order == :asc, do: "↑", else: "↓"}
              </th>
            </tr>
          </thead>
          <tbody>
            <%= for result <- @results do %>
              <tr class="border border-gray-300">
                <td class="border border-gray-300 px-4 py-2">{get_user_name(result.user_id)}</td>
                <td class="border border-gray-300 px-4 py-2">{result.result_type}</td>
                <td class="border border-gray-300 px-4 py-2">{result.correct}</td>
                <td class="border border-gray-300 px-4 py-2">{result.wrong}</td>
                <td class="border border-gray-300 px-4 py-2">{result.omitted}</td>
                <td class="border border-gray-300 px-4 py-2">
                  {Float.round(result.accuracy * 100, 2)}%
                </td>
                <td class="border border-gray-300 px-4 py-2">
                  {Float.round(result.reaction_time / 1000, 2)}s
                </td>
                <td class="border border-gray-300 px-4 py-2">{format_date(result.inserted_at)}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>
    </div>
    """
  end

  defp get_user_name(user_id) do
    case Beam.Repo.get(Beam.Accounts.User, user_id) do
      nil -> "Desconhecido"
      user -> user.name
    end
  end
end

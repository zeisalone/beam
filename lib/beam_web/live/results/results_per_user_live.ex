defmodule BeamWeb.Results.ResultsPerUserLive do
  use BeamWeb, :live_view
  alias Beam.Exercices

  def mount(params, _session, socket) do
    current_user = socket.assigns.current_user

    {user_id, user_name} =
      case current_user.type do
        "Paciente" -> {current_user.id, current_user.name}
        "Terapeuta" ->
          case get_patient(params["user_id"]) do
            nil -> {nil, "Desconhecido"}
            patient -> {patient.user.id, patient.user.name}
          end
        _ -> {nil, "Desconhecido"}
      end

    tasks = Exercices.list_tasks()
    results = if user_id, do: Exercices.list_results_by_user(user_id), else: []

    {:ok,
     assign(socket,
       results: results,
       all_results: results,
       user_id: user_id,
       user_name: user_name,
       tasks: tasks,
       full_screen?: false,
       selected_task_id: nil,
       selected_result_type: nil,
       sort_field: :inserted_at,
       sort_order: :desc
     )}
  end

  def handle_event("filter_task", %{"task_id" => task_id}, socket) do
    task_id = if task_id == "", do: nil, else: String.to_integer(task_id)

    filtered_results =
      socket.assigns.all_results
      |> filter_by_task(task_id)
      |> filter_by_result_type(socket.assigns.selected_result_type)

    {:noreply, assign(socket, results: filtered_results, selected_task_id: task_id)}
  end

  def handle_event("filter_result_type", %{"result_type" => result_type}, socket) do
    selected_result_type = if result_type == "", do: nil, else: result_type

    filtered_results =
      socket.assigns.all_results
      |> filter_by_task(socket.assigns.selected_task_id)
      |> filter_by_result_type(selected_result_type)

    {:noreply, assign(socket, results: filtered_results, selected_result_type: selected_result_type)}
  end

  def handle_event("sort_by", %{"field" => field_str}, socket) do
    field = String.to_existing_atom(field_str)
    new_sort_order =
      if socket.assigns.sort_field == field and socket.assigns.sort_order == :asc,
        do: :desc, else: :asc

    sorted_results =
      Enum.sort(socket.assigns.results, fn a, b ->
        compare =
          case compare_key(sort_key(field, a), sort_key(field, b)) do
            :eq -> NaiveDateTime.compare(a.inserted_at, b.inserted_at)
            res -> res
          end

        if new_sort_order == :asc, do: compare == :lt, else: compare == :gt
      end)

    {:noreply, assign(socket, results: sorted_results, sort_field: field, sort_order: new_sort_order)}
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

    {:noreply, assign(socket, results: sorted_results, sort_field: :inserted_at, sort_order: new_sort_order)}
  end

  defp sort_key(:task_name, r), do: Beam.Exercices.get_task_name(r.task_id)
  defp sort_key(:accuracy, r), do: r.accuracy
  defp sort_key(:inserted_at, r), do: r.inserted_at
  defp sort_key(_, r), do: r.inserted_at

  defp compare_key(a, b) when is_binary(a) do
    cond do
      a < b -> :lt
      a > b -> :gt
      true -> :eq
    end
  end
  defp compare_key(a, b) when is_float(a) do
    cond do
      a < b -> :lt
      a > b -> :gt
      true -> :eq
    end
  end
  defp compare_key(%NaiveDateTime{} = a, %NaiveDateTime{} = b), do: NaiveDateTime.compare(a, b)
  defp compare_key(_, _), do: :eq

  defp filter_by_task(results, nil), do: results
  defp filter_by_task(results, task_id), do: Enum.filter(results, &(&1.task_id == task_id))
  defp filter_by_result_type(results, nil), do: results
  defp filter_by_result_type(results, "Teste"), do: Enum.filter(results, &(&1.result_type == "Teste"))
  defp filter_by_result_type(results, "Treino"), do: Enum.filter(results, &String.starts_with?(&1.result_type, "Treino"))

  defp format_date(datetime) do
    datetime
    |> NaiveDateTime.to_date()
    |> Calendar.strftime("%d/%m/%Y")
  end

  defp get_patient(nil), do: nil
  defp get_patient(user_id) do
    case Beam.Repo.get_by(Beam.Accounts.Patient, user_id: user_id) do
      nil -> nil
      patient -> Beam.Repo.preload(patient, :user)
    end
  end

  defp sort_icon(current_field, current_order, field) do
    if current_field == field do
      if current_order == :asc, do: "↑", else: "↓"
    else
      ""
    end
  end

  def render(assigns) do
    ~H"""
    <div class="p-10">
      <h1 class="text-3xl font-bold mb-6">Resultados de {@user_name}</h1>

      <div class="flex flex-wrap items-end justify-between gap-6 mb-6">
        <div class="flex gap-4">
          <div class="bg-purple-100 text-purple-800 px-6 py-4 rounded shadow min-w-[180px]">
            <div class="text-sm font-semibold">Média de Precisão</div>
            <div class="text-2xl font-bold">
              <%= if Enum.any?(@results) do %>
                <%= Float.round(Enum.reduce(@results, 0, fn r, acc -> acc + r.accuracy end) / length(@results) * 100, 1) %>%
              <% else %> N/A <% end %>
            </div>
          </div>

          <div class="bg-blue-100 text-blue-800 px-6 py-4 rounded shadow min-w-[180px]">
            <div class="text-sm font-semibold">Média de Tempo de Reação</div>
            <div class="text-2xl font-bold">
              <%= if Enum.any?(@results) do %>
                <%= Float.round(Enum.reduce(@results, 0, fn r, acc -> acc + r.reaction_time end) / length(@results) / 1000, 2) %>s
              <% else %> N/A <% end %>
            </div>
          </div>
        </div>

        <div class="flex gap-4 flex-wrap items-end">
          <form phx-change="filter_task">
            <label for="task_filter" class="block text-sm font-medium text-gray-700 mb-1">Filtrar por Tarefa:</label>
            <select name="task_id" id="task_filter" class="p-2 border rounded w-60">
              <option value="">Todas as Tarefas</option>
              <%= for task <- @tasks do %>
                <option value={task.id} selected={@selected_task_id == task.id}><%= task.name %></option>
              <% end %>
            </select>
          </form>

          <form phx-change="filter_result_type">
            <label for="result_type_filter" class="block text-sm font-medium text-gray-700 mb-1">Filtrar por Tipo:</label>
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
              <th class="border border-gray-300 px-4 py-2">Tipo</th>
              <th class="border border-gray-300 px-4 py-2 cursor-pointer" phx-click="sort_by" phx-value-field="task_name">
                <div class="inline-flex items-center gap-1">
                  Tarefa <%= sort_icon(@sort_field, @sort_order, :task_name) %>
                </div>
              </th>
              <th class="border border-gray-300 px-4 py-2">Corretas</th>
              <th class="border border-gray-300 px-4 py-2">Erradas</th>
              <th class="border border-gray-300 px-4 py-2">Omitidas</th>
              <th class="border border-gray-300 px-4 py-2 cursor-pointer" phx-click="sort_by" phx-value-field="accuracy">
                <div class="inline-flex items-center gap-1">
                  Precisão <%= sort_icon(@sort_field, @sort_order, :accuracy) %>
                </div>
              </th>
              <th class="border border-gray-300 px-4 py-2">Tempo de Reação</th>
              <th class="border border-gray-300 px-4 py-2 cursor-pointer" phx-click="sort_by" phx-value-field="inserted_at">
                <div class="inline-flex items-center gap-1">
                  Data <%= sort_icon(@sort_field, @sort_order, :inserted_at) %>
                </div>
              </th>
            </tr>
          </thead>
          <tbody>
            <%= for result <- @results do %>
              <tr class="border border-gray-300">
                <td class="border border-gray-300 px-4 py-2"><%= result.result_type %></td>
                <td class="border border-gray-300 px-4 py-2"><%= Beam.Exercices.get_task_name(result.task_id) %></td>
                <td class="border border-gray-300 px-4 py-2"><%= result.correct %></td>
                <td class="border border-gray-300 px-4 py-2"><%= result.wrong %></td>
                <td class="border border-gray-300 px-4 py-2"><%= result.omitted %></td>
                <td class="border border-gray-300 px-4 py-2"><%= Float.round(result.accuracy * 100, 2) %>%</td>
                <td class="border border-gray-300 px-4 py-2"><%= Float.round(result.reaction_time / 1000, 2) %>s</td>
                <td class="border border-gray-300 px-4 py-2"><%= format_date(result.inserted_at) %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>
    </div>
    """
  end
end

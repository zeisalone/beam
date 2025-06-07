defmodule BeamWeb.Results.ResultsPerCategoryLive do
  use BeamWeb, :live_view
  alias Beam.Exercices

  def mount(params, _session, socket) do
    selected_category = params["category"]

    all_results =
      if selected_category do
        Exercices.list_results_by_category(selected_category)
        |> Enum.filter(fn r -> r.user.type == "Paciente" end)
      else
        []
      end

    users =
      all_results
      |> Enum.map(& &1.user)
      |> Enum.uniq_by(& &1.id)
      |> Enum.sort_by(& &1.name)

    tasks =
      all_results
      |> Enum.map(& &1.task)
      |> Enum.uniq_by(& &1.id)
      |> Enum.sort_by(& &1.name)

    sorted_results = Enum.sort_by(all_results, & &1.inserted_at, :desc)

    {:ok,
     assign(socket,
       selected_category: selected_category,
       results: sorted_results,
       all_results: all_results,
       users: users,
       tasks: tasks,
       selected_user_id: nil,
       selected_task_id: nil,
       selected_result_type: nil,
       sort_field: :inserted_at,
       sort_order: :desc,
       full_screen?: false
     )}
  end

  def handle_event("filter_user", %{"user_id" => user_id}, socket) do
    user_id = if user_id == "", do: nil, else: String.to_integer(user_id)

    results =
      socket.assigns.all_results
      |> filter_by_user(user_id)
      |> filter_by_task(socket.assigns.selected_task_id)
      |> filter_by_result_type(socket.assigns.selected_result_type)

    {:noreply, assign(socket, results: results, selected_user_id: user_id)}
  end

  def handle_event("filter_task", %{"task_id" => task_id}, socket) do
    task_id = if task_id == "", do: nil, else: String.to_integer(task_id)

    results =
      socket.assigns.all_results
      |> filter_by_user(socket.assigns.selected_user_id)
      |> filter_by_task(task_id)
      |> filter_by_result_type(socket.assigns.selected_result_type)

    {:noreply, assign(socket, results: results, selected_task_id: task_id)}
  end

  def handle_event("filter_result_type", %{"result_type" => type}, socket) do
    selected_result_type = if type == "", do: nil, else: type

    results =
      socket.assigns.all_results
      |> filter_by_user(socket.assigns.selected_user_id)
      |> filter_by_task(socket.assigns.selected_task_id)
      |> filter_by_result_type(selected_result_type)

    {:noreply, assign(socket, results: results, selected_result_type: selected_result_type)}
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

    {:noreply,
     assign(socket, results: sorted_results, sort_field: field, sort_order: new_sort_order)}
  end

  defp filter_by_user(results, nil), do: results
  defp filter_by_user(results, user_id), do: Enum.filter(results, &(&1.user.id == user_id))

  defp filter_by_task(results, nil), do: results
  defp filter_by_task(results, task_id), do: Enum.filter(results, &(&1.task.id == task_id))

  defp filter_by_result_type(results, nil), do: results
  defp filter_by_result_type(results, "Teste"), do: Enum.filter(results, &(&1.result_type == "Teste"))
  defp filter_by_result_type(results, "Treino"), do: Enum.filter(results, &String.starts_with?(&1.result_type, "Treino"))

  defp sort_key(:user_name, r), do: r.user.name
  defp sort_key(:task_name, r), do: r.task.name
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

  defp format_date(datetime) do
    datetime
    |> NaiveDateTime.to_date()
    |> Calendar.strftime("%d/%m/%Y")
  end

  defp sort_icon(current_field, current_order, field) do
    if current_field == field do
      if current_order == :asc, do: "↑", else: "↓"
    else
      ""
    end
  end

  defp calculate_average_accuracy(results) do
    if Enum.any?(results) do
      Enum.reduce(results, 0.0, fn r, acc -> acc + r.accuracy end) / length(results)
    else
      nil
    end
  end

  defp calculate_average_reaction_time(results) do
    if Enum.any?(results) do
      Enum.reduce(results, 0.0, fn r, acc -> acc + r.reaction_time end) / length(results)
    else
      nil
    end
  end

  def render(assigns) do
    ~H"""
    <div class="p-10">
      <h1 class="text-3xl font-bold mb-6">Resultados por Categoria</h1>

      <%= if @selected_category do %>
        <p class="mb-4 text-lg text-gray-700">Categoria selecionada: <strong><%= @selected_category %></strong></p>
      <% else %>
        <p class="text-center text-gray-500">Nenhuma categoria selecionada.</p>
      <% end %>

      <%= if @results != [] do %>
        <div class="flex gap-6 mb-6">
          <div class="bg-purple-100 text-purple-800 px-8 py-3 rounded shadow min-w-[240px] h-24 flex flex-col justify-center">
            <div class="text-sm font-semibold">Média de Precisão</div>
            <div class="text-2xl font-bold">
              <%= Float.round(calculate_average_accuracy(@results) * 100, 1) %>%
            </div>
          </div>

          <div class="bg-blue-100 text-blue-800 px-8 py-3 rounded shadow min-w-[240px] h-24 flex flex-col justify-center">
            <div class="text-sm font-semibold">Média de Tempo de Reação</div>
            <div class="text-2xl font-bold">
              <%= Float.round(calculate_average_reaction_time(@results) / 1000, 2) %>s
            </div>
          </div>

          <div class="bg-green-100 text-green-800 px-8 py-3 rounded shadow min-w-[240px] h-24 flex flex-col justify-center">
            <div class="text-sm font-semibold">Nº de Exercícios Feitos</div>
            <div class="text-2xl font-bold">
              <%= length(@results) %>
            </div>
          </div>
        </div>
      <% end %>

      <div class="flex gap-6 mb-6">
        <form phx-change="filter_user">
          <label for="user_filter" class="block text-sm font-medium text-gray-700 mb-1">Filtrar por Utilizador:</label>
          <select name="user_id" id="user_filter" class="p-2 border rounded w-60">
            <option value="">Todos os Pacientes</option>
            <%= for user <- @users do %>
              <option value={user.id} selected={@selected_user_id == user.id}><%= user.name %></option>
            <% end %>
          </select>
        </form>

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

      <%= if @results == [] do %>
        <p class="text-center text-gray-500 mt-4">Nenhum resultado encontrado.</p>
      <% else %>
        <table class="w-full border-collapse border border-gray-300 mt-4">
          <thead>
            <tr class="bg-gray-200">
              <th class="border border-gray-300 px-4 py-2 cursor-pointer" phx-click="sort_by" phx-value-field="user_name">
                <div class="inline-flex items-center gap-1">Utilizador <%= sort_icon(@sort_field, @sort_order, :user_name) %></div>
              </th>
              <th class="border border-gray-300 px-4 py-2 cursor-pointer" phx-click="sort_by" phx-value-field="task_name">
                <div class="inline-flex items-center gap-1">Tarefa <%= sort_icon(@sort_field, @sort_order, :task_name) %></div>
              </th>
              <th class="border border-gray-300 px-4 py-2">Tipo</th>
              <th class="border border-gray-300 px-4 py-2">Corretas</th>
              <th class="border border-gray-300 px-4 py-2">Erradas</th>
              <th class="border border-gray-300 px-4 py-2">Omitidas</th>
              <th class="border border-gray-300 px-4 py-2 cursor-pointer" phx-click="sort_by" phx-value-field="accuracy">
                <div class="inline-flex items-center gap-1">Precisão <%= sort_icon(@sort_field, @sort_order, :accuracy) %></div>
              </th>
              <th class="border border-gray-300 px-4 py-2">Tempo de Reação</th>
              <th class="border border-gray-300 px-4 py-2 cursor-pointer" phx-click="sort_by" phx-value-field="inserted_at">
                <div class="inline-flex items-center gap-1">Data <%= sort_icon(@sort_field, @sort_order, :inserted_at) %></div>
              </th>
            </tr>
          </thead>
          <tbody>
            <%= for result <- @results do %>
              <tr class="border border-gray-300">
                <td class="border border-gray-300 px-4 py-2"><%= result.user.name %></td>
                <td class="border border-gray-300 px-4 py-2"><%= result.task.name %></td>
                <td class="border border-gray-300 px-4 py-2"><%= result.result_type %></td>
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

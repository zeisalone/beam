defmodule BeamWeb.Results.ResultsPerUserLive do
  use BeamWeb, :live_view
  alias Beam.Exercices

  @impl true
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
    average_general = Exercices.average_accuracy_per_task()
    average_general_reaction = Exercices.average_reaction_time_per_task()
    task_accuracies =
      if user_id, do: Exercices.average_accuracy_per_task_for_user(user_id), else: []
    task_reaction_times =
      if user_id, do: Exercices.average_reaction_time_per_task_for_user(user_id), else: []
    test_accuracies =
      if user_id, do: Exercices.average_test_accuracy_per_task_for_user(user_id), else: []
    test_accuracies_general = Exercices.average_test_accuracy_per_task()
    duo_test_accuracies = duo_test_chart_data(test_accuracies, test_accuracies_general)

    {:ok,
     assign(socket,
       results: results,
       all_results: results,
       user_id: user_id,
       user_name: user_name,
       tasks: tasks,
       task_accuracies: task_accuracies,
       task_reaction_times: task_reaction_times,
       visible_task_ids: Enum.map(tasks, & &1.id),
       show_accuracy_chart?: false,
       show_reaction_chart?: false,
       show_duo_test_chart?: false,
       all_task_accuracies:   task_accuracies,
       all_task_reaction_times: task_reaction_times,
       general_accuracies: average_general,
       general_reaction_times: average_general_reaction,
       full_screen?: false,
       selected_task_id: nil,
       selected_result_type: nil,
       sort_field: :inserted_at,
       show_task_filter_panel: false,
       sort_order: :desc,
       show_compare_panel: false,
       compare_mode: "none",
       test_accuracies: test_accuracies,
       test_accuracies_general: test_accuracies_general,
       duo_test_accuracies: duo_test_accuracies
     )}
  end


  @impl true
  def handle_event("update_task_filters", %{"task_ids" => task_ids}, socket) do
    ids = Enum.map(task_ids, &String.to_integer/1)
    filtered_accuracies = Enum.filter(socket.assigns.all_task_accuracies,   &(&1.task_id in ids))
    filtered_reactions  = Enum.filter(socket.assigns.all_task_reaction_times, &(&1.task_id in ids))

    {:noreply,
     assign(socket,
       visible_task_ids: ids,
       task_accuracies: filtered_accuracies,
       task_reaction_times: filtered_reactions
     )}
  end

  @impl true
  def handle_event("toggle_duo_test_chart", _params, socket) do
    {:noreply, assign(socket, show_duo_test_chart?: !socket.assigns.show_duo_test_chart?)}
  end

  @impl true
  def handle_event("toggle_accuracy_chart", _params, socket) do
    {:noreply, assign(socket, show_accuracy_chart?: !socket.assigns.show_accuracy_chart?)}
  end

  @impl true
  def handle_event("toggle_reaction_chart", _params, socket) do
    {:noreply, assign(socket, show_reaction_chart?: !socket.assigns.show_reaction_chart?)}
  end

  @impl true
  def handle_event("toggle_task_filter_panel", _params, socket) do
    {:noreply, assign(socket, show_task_filter_panel: !socket.assigns.show_task_filter_panel)}
  end

  @impl true
  def handle_event("toggle_compare_panel", _params, socket) do
    {:noreply, assign(socket, show_compare_panel: !socket.assigns.show_compare_panel)}
  end

  @impl true
  def handle_event("set_compare_mode", %{"compare_mode" => mode}, socket) do
    {:noreply, assign(socket, compare_mode: mode, show_compare_panel: false)}
  end

  @impl true
  def handle_event("filter_task", %{"task_id" => task_id}, socket) do
    task_id = if task_id == "", do: nil, else: String.to_integer(task_id)
    filtered = socket.assigns.all_results
      |> filter_by_task(task_id)
      |> filter_by_result_type(socket.assigns.selected_result_type)

    {:noreply, assign(socket, results: filtered, selected_task_id: task_id)}
  end

  @impl true
  def handle_event("filter_result_type", %{"result_type" => result_type}, socket) do
    sel = if result_type == "", do: nil, else: result_type
    filtered = socket.assigns.all_results
      |> filter_by_task(socket.assigns.selected_task_id)
      |> filter_by_result_type(sel)

    {:noreply, assign(socket, results: filtered, selected_result_type: sel)}
  end

  @impl true
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

  @impl true
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
  defp sort_key(:accuracy, r),     do: r.accuracy
  defp sort_key(:inserted_at, r),  do: r.inserted_at
  defp sort_key(_, _),             do: nil

  defp compare_key(a, b) when is_binary(a) and is_binary(b) do
    cond do
      a < b -> :lt
      a > b -> :gt
      true   -> :eq
    end
  end
  defp compare_key(a, b) when is_number(a) and is_number(b) do
    cond do
      a < b -> :lt
      a > b -> :gt
      true   -> :eq
    end
  end
  defp compare_key(%NaiveDateTime{} = a, %NaiveDateTime{} = b), do: NaiveDateTime.compare(a, b)
  defp compare_key(_, _), do: :eq

  defp filter_by_task(results, nil), do: results
  defp filter_by_task(results, id),  do: Enum.filter(results, &(&1.task_id == id))

  defp filter_by_result_type(results, nil),    do: results
  defp filter_by_result_type(results, "Teste"), do: Enum.filter(results, &(&1.result_type == "Teste"))
  defp filter_by_result_type(results, "Treino"), do: Enum.filter(results, &String.starts_with?(&1.result_type, "Treino"))

  defp format_date(dt), do: dt |> NaiveDateTime.to_date() |> Calendar.strftime("%d/%m/%Y")

  defp get_patient(nil), do: nil
  defp get_patient(user_id) do
    Beam.Repo.get_by(Beam.Accounts.Patient, user_id: user_id)
    |> case do
      nil      -> nil
      patient  -> Beam.Repo.preload(patient, :user)
    end
  end

  defp chart_data_with_compare(assigns) do
    compare_mode = Map.get(assigns, :compare_mode, "none")
    case compare_mode do
      "media_geral" ->
        user_data = assigns.task_accuracies
        general_data = assigns.general_accuracies

        general_map = Map.new(general_data, &{&1.task_name, &1.avg_accuracy})

        Enum.map(user_data, fn d ->
          %{
            task_name: d.task_name,
            avg_accuracy: d.avg_accuracy,
            general_avg_accuracy: Map.get(general_map, d.task_name)
          }
        end)
      _ ->
        assigns.task_accuracies
    end
  end

  defp chart_reaction_data_with_compare(assigns) do
    compare_mode = Map.get(assigns, :compare_mode, "none")
    case compare_mode do
      "media_geral" ->
        user_data = assigns.task_reaction_times
        general_data = assigns.general_reaction_times

        general_map = Map.new(general_data, &{&1.task_name, &1.avg_reaction_time})

        Enum.map(user_data, fn d ->
          %{
            task_name: d.task_name,
            avg_reaction_time: d.avg_reaction_time,
            general_avg_reaction_time: Map.get(general_map, d.task_name)
          }
        end)
      _ ->
        assigns.task_reaction_times
    end
  end

  defp duo_test_chart_data(patient, general) do
    general_map = Map.new(general, &{&1.task_name, &1.avg_accuracy})
    Enum.map(patient, fn d ->
      %{
        task_name: d.task_name,
        avg_accuracy: d.avg_accuracy,
        general_avg_accuracy: Map.get(general_map, d.task_name)
      }
    end)
  end

  defp duo_test_chart_data_with_compare(assigns) do
    compare_mode = Map.get(assigns, :compare_mode, "none")

    filtered =
      Enum.filter(assigns.test_accuracies, &(&1.task_id in assigns.visible_task_ids))

    general_map =
      Map.new(assigns.test_accuracies_general, &{&1.task_name, &1.avg_accuracy})

    case compare_mode do
      "media_geral" ->
        Enum.map(filtered, fn d ->
          %{
            task_name: d.task_name,
            avg_accuracy: d.avg_accuracy,
            general_avg_accuracy: Map.get(general_map, d.task_name)
          }
        end)
      _ -> filtered
    end
  end


  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-10">
      <h1 class="text-3xl font-bold mb-6">Resultados de {@user_name}</h1>

      <div class="flex gap-4 mb-4">
        <button phx-click="toggle_accuracy_chart" class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded shadow">
          <%= if @show_accuracy_chart?, do: "Esconder Gráfico de Precisão", else: "Ver Gráfico de Precisão" %>
        </button>
        <button phx-click="toggle_reaction_chart" class="bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded shadow">
          <%= if @show_reaction_chart?, do: "Esconder Gráfico de Reação", else: "Ver Gráfico de Reação" %>
        </button>
        <button phx-click="toggle_duo_test_chart" class="bg-yellow-600 hover:bg-yellow-700 text-white px-4 py-2 rounded shadow">
          <%= if @show_duo_test_chart?, do: "Esconder Gráfico de Testes", else: "Ver Gráfico de Testes" %>
        </button>
      </div>

      <%= if @show_accuracy_chart? do %>
        <.chart_modal title="Precisão Média por Tarefa" event="toggle_accuracy_chart" hook="AccuracyChart" chart_data={chart_data_with_compare(assigns)} field="avg_accuracy" label="Precisão Média (%)" tasks={@tasks} visible_task_ids={@visible_task_ids} show_filter_panel={@show_task_filter_panel} show_compare_panel={@show_compare_panel} compare_mode={@compare_mode} user_name={@user_name} />
      <% end %>

      <%= if @show_reaction_chart? do %>
        <.chart_modal title="Tempo Médio de Reação por Tarefa" event="toggle_reaction_chart" hook="ReactionChart" chart_data={chart_reaction_data_with_compare(assigns)} field="avg_reaction_time" label="Tempo Médio (ms)" tasks={@tasks} visible_task_ids={@visible_task_ids} show_filter_panel={@show_task_filter_panel} show_compare_panel={@show_compare_panel} compare_mode={@compare_mode} user_name={@user_name} />
      <% end %>

      <%= if @show_duo_test_chart? do %>
        <.chart_modal title="Precisão dos Testes" event="toggle_duo_test_chart" hook="AccuracyChart" chart_data={duo_test_chart_data_with_compare(assigns)} field="avg_accuracy" label="Precisão Média (%)" tasks={@tasks} visible_task_ids={@visible_task_ids} show_filter_panel={@show_task_filter_panel} show_compare_panel={@show_compare_panel} compare_mode={@compare_mode} user_name={@user_name} />
      <% end %>

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

  attr :title, :string, required: true
  attr :event, :string, required: true
  attr :hook, :string, required: true
  attr :chart_data, :any, required: true
  attr :field, :string, required: true
  attr :label, :string, required: true
  attr :user_name, :string, required: true
  attr :tasks, :list, required: true
  attr :compare_mode, :string, required: true
  attr :show_compare_panel, :boolean, required: true
  attr :visible_task_ids, :list, required: true
  attr :show_filter_panel, :boolean, required: true

  defp chart_modal(assigns) do
    ~H"""
    <div id="chart-modal" class="fixed inset-0 z-50 bg-black bg-opacity-50 flex items-center justify-center">
      <div class="bg-white rounded-2xl shadow-xl w-full max-w-6xl h-[75vh] overflow-hidden relative">
        <div class="flex items-center justify-between px-6 py-3 border-b ">
          <h3 class="text-2xl font-bold"><%= @title %></h3>
          <div class="flex items-center gap-2">
            <.button phx-click="toggle_compare_panel" id="compare-btn">Comparar</.button>
            <.button phx-click="toggle_task_filter_panel" id="tasks-btn">Tarefas</.button>
            <button phx-click={@event} class="text-gray-500 hover:text-red-600 text-2xl font-bold" aria-label="Fechar">×</button>
          </div>
        </div>

        <%= if @show_filter_panel do %>
          <div class= "absolute top-16 right-6 w-64 bg-white border rounded shadow-lg p-4 z-10 overflow-y-auto max-h-[60vh] transition-all">
            <h4 class="font-semibold mb-2">Filtrar Tarefas</h4>
            <form phx-change="update_task_filters">
              <div class="space-y-1 text-sm">
                <%= for task <- @tasks do %>
                  <label class="flex items-center">
                    <input type="checkbox"
                          name="task_ids[]"
                          value={task.id}
                          checked={task.id in @visible_task_ids}
                          class="mr-2 rounded text-blue-600"/>
                    <span><%= task.name %></span>
                  </label>
                <% end %>
              </div>
            </form>
          </div>
        <% end %>

        <%= if @show_compare_panel do %>
          <div class={
            if @show_filter_panel do
              "absolute top-16 right-72 w-64 bg-white border rounded shadow-lg p-4 z-10 overflow-y-auto max-h-[60vh] transition-all"
            else
              "absolute top-16 right-32 w-64 bg-white border rounded shadow-lg p-4 z-10 overflow-y-auto max-h-[60vh] transition-all"
            end
          }>
            <h4 class="font-semibold mb-2">Comparar Com</h4>
            <form phx-change="set_compare_mode">
              <div class="space-y-2">
                <label class="flex items-center text-sm">
                  <input type="radio" name="compare_mode" value="none"
                    checked={@compare_mode == "none"} class="mr-2" />
                  Sem Comparação
                </label>
                <label class="flex items-center text-sm">
                  <input type="radio" name="compare_mode" value="media_geral"
                    checked={@compare_mode == "media_geral"} class="mr-2" />
                  Média Geral
                </label>
              </div>
            </form>
          </div>
        <% end %>

        <div class="absolute top-12 inset-x-0 bottom-4 p-4 flex items-center justify-center">
          <canvas id={"chart-#{@hook}"}
                  phx-hook={@hook}
                  data-chart={Jason.encode!(@chart_data)}
                  data-field={@field}
                  data-label={@label}
                  data-patient={@user_name}
                  class="max-w-[85%] h-full"/>
        </div>
      </div>
    </div>
    """
  end


  defp sort_icon(current_field, current_order, field) do
    if current_field == field do
      if current_order == :asc, do: "↑", else: "↓"
    else
      ""
    end
  end
end

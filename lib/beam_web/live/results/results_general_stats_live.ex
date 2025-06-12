defmodule BeamWeb.Results.ResultsGeneralStatsLive do
  use BeamWeb, :live_view

  alias Beam.Accounts
  alias Beam.Exercices

  @age_ranges [
    {"0-6", 0..6},
    {"7-12", 7..12},
    {"13-18", 13..18},
    {"19-29", 19..29},
    {"30-44", 30..44},
    {"45-59", 45..59},
    {"60+", 60..150}
  ]

  @genders ["Masculino", "Feminino", "Outro"]
  @education_levels ["Pré-Primaria", "1º ciclo", "2º ciclo", "3º ciclo", "Secundário", "Universitário"]

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    task_accuracies = Exercices.average_accuracy_per_task() |> Enum.sort_by(& &1.task_id)
    task_reaction_times = Exercices.average_reaction_time_per_task() |> Enum.sort_by(& &1.task_id)

    task_accuracies_my =
      if current_user.type == "Terapeuta" do
        Exercices.average_accuracy_per_task(%{therapist_user_id: current_user.id}) |> Enum.sort_by(& &1.task_id)
      else
        []
      end

    task_reaction_times_my =
      if current_user.type == "Terapeuta" do
        Exercices.average_reaction_time_per_task(%{therapist_user_id: current_user.id}) |> Enum.sort_by(& &1.task_id)
      else
        []
      end

    age_distribution_all = Accounts.age_distribution_all_patients()
    age_distribution_mine = Accounts.age_distribution_for_therapist(current_user.id)

    stats = %{
      weekly_exercises: Exercices.count_exercises_this_week(),
      weekly_active_patients: Exercices.count_active_patients_this_week(current_user.id),
      average_patient_age: Accounts.average_patient_age(),
      average_my_patient_age: Accounts.average_patient_age_for_therapist(current_user.id)
    }

    {:ok,
     assign(socket,
       full_screen?: false,
       open_help: false,
       stats: stats,
       show_chart?: false,
       show_chart_my?: false,
       show_reaction_chart?: false,
       show_reaction_chart_my?: false,
       show_age_pie_all?: false,
       show_age_pie_mine?: false,
       task_accuracies: task_accuracies,
       task_reaction_times: task_reaction_times,
       task_accuracies_my: task_accuracies_my,
       task_reaction_times_my: task_reaction_times_my,
       age_distribution_all: age_distribution_all,
       age_distribution_mine: age_distribution_mine,
       current_user: current_user,
       selected_age_range: "",
       selected_gender: "",
       selected_education: "",
       age_ranges: @age_ranges,
       genders: @genders,
       education_levels: @education_levels
     )}
  end

  @impl true
  def handle_event("toggle_chart", _params, socket) do
    {:noreply, assign(socket, show_chart?: !socket.assigns.show_chart?)}
  end

  @impl true
  def handle_event("toggle_reaction_chart", _params, socket) do
    {:noreply, assign(socket, show_reaction_chart?: !socket.assigns.show_reaction_chart?)}
  end

  @impl true
  def handle_event("toggle_chart_my", _params, socket) do
    {:noreply, assign(socket, show_chart_my?: !socket.assigns.show_chart_my?)}
  end

  @impl true
  def handle_event("toggle_reaction_chart_my", _params, socket) do
    {:noreply, assign(socket, show_reaction_chart_my?: !socket.assigns.show_reaction_chart_my?)}
  end

  @impl true
  def handle_event("toggle_age_pie_all", _params, socket) do
    {:noreply, assign(socket, show_age_pie_all?: !socket.assigns.show_age_pie_all?)}
  end

  @impl true
  def handle_event("toggle_age_pie_mine", _params, socket) do
    {:noreply, assign(socket, show_age_pie_mine?: !socket.assigns.show_age_pie_mine?)}
  end

  @impl true
  def handle_event("filter", %{"age_range" => age, "gender" => gender, "education" => education}, socket) do
    age_range =
      case Enum.find(@age_ranges, fn {label, _} -> label == age end) do
        {_label, %Range{first: first, last: last}} -> {first, last}
        nil -> nil
      end

    filters = %{
      age_range: age_range,
      gender: if(gender in ["", "Todos os géneros"], do: nil, else: gender),
      education: if(education in ["", "Todos os níveis"], do: nil, else: education)
    }

    filtered_accuracies = Exercices.average_accuracy_per_task(filters) |> Enum.sort_by(& &1.task_id)
    filtered_reactions = Exercices.average_reaction_time_per_task(filters) |> Enum.sort_by(& &1.task_id)

    filtered_accuracies_my =
      if socket.assigns.current_user.type == "Terapeuta" do
        Exercices.average_accuracy_per_task(Map.put(filters, :therapist_user_id, socket.assigns.current_user.id))
        |> Enum.sort_by(& &1.task_id)
      else
        []
      end

    filtered_reactions_my =
      if socket.assigns.current_user.type == "Terapeuta" do
        Exercices.average_reaction_time_per_task(Map.put(filters, :therapist_user_id, socket.assigns.current_user.id))
        |> Enum.sort_by(& &1.task_id)
      else
        []
      end

    {:noreply,
     assign(socket,
       selected_age_range: age,
       selected_gender: gender,
       selected_education: education,
       task_accuracies: filtered_accuracies,
       task_reaction_times: filtered_reactions,
       task_accuracies_my: filtered_accuracies_my,
       task_reaction_times_my: filtered_reactions_my
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-10 text-center">
      <div class="mx-auto max-w-4xl bg-white border border-gray-300 rounded-xl shadow-lg p-6 space-y-6">
        <h2 class="text-3xl font-bold mb-2">Estatísticas Gerais</h2>
        <p class="text-gray-700">Esta secção apresenta estatísticas gerais de desempenho na aplicação.</p>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-6">
          <div class="border rounded-lg shadow p-4 text-left bg-gray-50 relative">
            <p class="text-gray-500 text-sm">Exercícios feitos esta semana</p>
            <p class="text-2xl font-bold text-gray-900 mt-1"><%= @stats.weekly_exercises %></p>
          </div>
          <div class="border rounded-lg shadow p-4 text-left bg-gray-50 relative">
            <p class="text-gray-500 text-sm">Pacientes ativos esta semana</p>
            <p class="text-2xl font-bold text-gray-900 mt-1"><%= @stats.weekly_active_patients %></p>
          </div>

          <div class="border rounded-lg shadow p-4 text-left bg-gray-50 relative">
            <p class="text-gray-500 text-sm">Idade média dos pacientes</p>
            <p class="text-2xl font-bold text-gray-900 mt-1">
              <%= if @stats.average_patient_age do %>
                <%= Float.round(@stats.average_patient_age, 1) %> anos
              <% else %>
                N/A
              <% end %>
            </p>
            <button phx-click="toggle_age_pie_all" class="absolute bottom-1 right-1 text-black text-xs leading-none p-0 m-0">Ver em Detalhe</button>
          </div>

          <%= if @current_user.type == "Terapeuta" do %>
            <div class="border rounded-lg shadow p-4 text-left bg-gray-50 relative">
              <p class="text-gray-500 text-sm">Idade média dos meus pacientes</p>
              <p class="text-2xl font-bold text-gray-900 mt-1">
                <%= if @stats.average_my_patient_age do %>
                  <%= Float.round(@stats.average_my_patient_age, 1) %> anos
                <% else %>
                  N/A
                <% end %>
              </p>
              <button phx-click="toggle_age_pie_mine" class="absolute bottom-1 right-1 text-black text-xs leading-none p-0 m-0">Ver em Detalhe</button>
            </div>
          <% end %>
        </div>

        <div class="mt-8 flex justify-center">
          <div class="bg-white shadow-md rounded-xl px-8 py-6 w-full max-w-lg flex flex-col items-center gap-5 border">
            <h3 class="text-xl font-semibold mb-2 text-gray-800">Gráficos</h3>
            <div class="flex flex-col gap-3 w-full">
              <button phx-click="toggle_chart" class="w-full min-w-[230px] text-base bg-gray-900 hover:bg-blue-900 text-white font-semibold px-4 py-2 rounded-lg shadow transition-all">
                Precisão (Geral)
              </button>
              <button phx-click="toggle_reaction_chart" class="w-full min-w-[230px] text-base bg-gray-900 hover:bg-blue-900 text-white font-semibold px-4 py-2 rounded-lg shadow transition-all">
                Tempo de Reação (Geral)
              </button>
              <button phx-click="toggle_chart_my" class="w-full min-w-[230px] text-base bg-gray-900 hover:bg-blue-900 text-white font-semibold px-4 py-2 rounded-lg shadow transition-all border-2 border-blue-500">
                Precisão (Só meus pacientes)
              </button>
              <button phx-click="toggle_reaction_chart_my" class="w-full min-w-[230px] text-base bg-gray-900 hover:bg-blue-900 text-white font-semibold px-4 py-2 rounded-lg shadow transition-all border-2 border-purple-500">
                Tempo de Reação (Só meus pacientes)
              </button>
            </div>
          </div>
        </div>

        <%= if @show_chart? do %>
          <.chart_modal title="Precisão Média por Tarefa (Geral)" event="toggle_chart" hook="AccuracyStatChart"
            chart_data={@task_accuracies} field="avg_accuracy" label="Precisão Média (%)"
            age_ranges={@age_ranges} genders={@genders} education_levels={@education_levels}
            selected_age_range={@selected_age_range} selected_gender={@selected_gender}
            selected_education={@selected_education} />
        <% end %>

        <%= if @show_reaction_chart? do %>
          <.chart_modal title="Tempo Médio de Reação por Tarefa (Geral)" event="toggle_reaction_chart" hook="ReactionStatChart"
            chart_data={@task_reaction_times} field="avg_reaction_time" label="Tempo Médio (ms)"
            age_ranges={@age_ranges} genders={@genders} education_levels={@education_levels}
            selected_age_range={@selected_age_range} selected_gender={@selected_gender}
            selected_education={@selected_education} />
        <% end %>

        <%= if @show_chart_my? do %>
          <.chart_modal title="Precisão Média por Tarefa (Só meus pacientes)" event="toggle_chart_my" hook="AccuracyStatChart"
            chart_data={@task_accuracies_my} field="avg_accuracy" label="Precisão Média (%)"
            age_ranges={@age_ranges} genders={@genders} education_levels={@education_levels}
            selected_age_range={@selected_age_range} selected_gender={@selected_gender}
            selected_education={@selected_education} />
        <% end %>

        <%= if @show_reaction_chart_my? do %>
          <.chart_modal title="Tempo Médio de Reação por Tarefa (Só meus pacientes)" event="toggle_reaction_chart_my" hook="ReactionStatChart"
            chart_data={@task_reaction_times_my} field="avg_reaction_time" label="Tempo Médio (ms)"
            age_ranges={@age_ranges} genders={@genders} education_levels={@education_levels}
            selected_age_range={@selected_age_range} selected_gender={@selected_gender}
            selected_education={@selected_education} />
        <% end %>

        <%= if @show_age_pie_all? do %>
          <.pie_modal event="toggle_age_pie_all" hook="PieChart"
            chart_data={@age_distribution_all} title="Distribuição Etária (Todos os Pacientes)" />
        <% end %>

        <%= if @show_age_pie_mine? do %>
          <.pie_modal event="toggle_age_pie_mine" hook="PieChart"
            chart_data={@age_distribution_mine} title="Distribuição Etária (Meus Pacientes)" />
        <% end %>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :event, :string, required: true
  attr :hook, :string, required: true
  attr :chart_data, :any, required: true
  defp pie_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 bg-black bg-opacity-50 flex items-center justify-center">
      <div class="bg-white rounded-lg shadow-lg w-full max-w-xl p-6 relative">
        <button phx-click={@event} class="absolute top-3 right-3 text-gray-500 hover:text-red-600 text-xl font-bold">×</button>
        <h3 class="text-xl font-bold mb-4"><%= @title %></h3>
        <canvas id={"chart-#{@hook}"} phx-hook="PieChart" data-chart={Jason.encode!(@chart_data)} class="w-full h-96"></canvas>
      </div>
    </div>
    """
  end
  attr :title, :string, required: true
  attr :event, :string, required: true
  attr :hook, :string, required: true
  attr :chart_data, :any, required: true
  attr :field, :string, required: true
  attr :label, :string, required: true
  attr :age_ranges, :list, required: true
  attr :genders, :list, required: true
  attr :education_levels, :list, required: true
  attr :selected_age_range, :string, required: true
  attr :selected_gender, :string, required: true
  attr :selected_education, :string, required: true

  defp chart_modal(assigns) do
    ~H"""
    <div id="chart-modal" class="fixed inset-0 z-50 bg-black bg-opacity-50 flex items-center justify-center">
      <div class="bg-white rounded-lg shadow-lg w-full max-w-4xl p-6 relative">
        <button phx-click={@event} class="absolute top-3 right-3 text-gray-500 hover:text-red-600 text-xl font-bold" aria-label="Fechar">
          ×
        </button>

        <h3 class="text-xl font-bold mb-4"><%= @title %></h3>

        <form phx-change="filter">
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
            <select name="age_range" class="p-2 border rounded">
              <option value="">Todas as idades</option>
              <%= for {label, _range} <- @age_ranges do %>
                <option value={label} selected={@selected_age_range == label}><%= label %></option>
              <% end %>
            </select>

            <select name="gender" class="p-2 border rounded">
              <option value="">Todos os géneros</option>
              <%= for gender <- @genders do %>
                <option value={gender} selected={@selected_gender == gender}><%= gender %></option>
              <% end %>
            </select>

            <select name="education" class="p-2 border rounded">
              <option value="">Todos os níveis</option>
              <%= for level <- @education_levels do %>
                <option value={level} selected={@selected_education == level}><%= level %></option>
              <% end %>
            </select>
          </div>
        </form>

        <canvas id={"chart-#{@hook}"} phx-hook={@hook} data-chart={Jason.encode!(@chart_data)} data-field={@field} data-label={@label} class="w-full h-96"></canvas>

        <%= if Enum.any?(@chart_data, fn t -> Map.get(t, String.to_existing_atom(@field)) |> is_nil() end) do %>
          <p class="text-xs text-gray-500 mt-2 italic">* Algumas tarefas não têm dados disponíveis.</p>
        <% end %>
      </div>
    </div>
    """
  end
end

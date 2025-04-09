defmodule BeamWeb.Results.ResultsGeneralStatsLive do
  use BeamWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    stats =
      if current_user.type == "Terapeuta" do
        %{
          weekly_exercises: Beam.Exercices.count_exercises_this_week(),
          weekly_active_patients: Beam.Exercices.count_active_patients_this_week(current_user.id)
        }
      else
        %{
          weekly_exercises: 0,
          weekly_active_patients: 0
        }
      end

    {:ok,
     assign(socket,
       full_screen?: false,
       open_help: false,
       stats: stats,
       current_user: current_user
     )}
  end


  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-10 text-center">
      <div class="mx-auto max-w-xl bg-white border border-gray-300 rounded-xl shadow-lg p-6 space-y-6">
        <h2 class="text-3xl font-bold mb-2">Estatísticas Gerais</h2>
        <p class="text-gray-700">Esta secção apresenta estatísticas gerais de desempenho na aplicação.</p>
        <p class="text-gray-500 italic">(Ainda em construção)</p>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-6">
          <div class="border rounded-lg shadow p-4 text-left bg-gray-50">
            <p class="text-gray-500 text-sm">Exercícios feitos esta semana</p>
            <p class="text-2xl font-bold text-gray-900 mt-1"><%= @stats.weekly_exercises %></p>
          </div>
          <div class="border rounded-lg shadow p-4 text-left bg-gray-50">
            <p class="text-gray-500 text-sm">Pacientes ativos esta semana</p>
            <p class="text-2xl font-bold text-gray-900 mt-1"><%= @stats.weekly_active_patients %></p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end

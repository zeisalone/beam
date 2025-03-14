defmodule BeamWeb.Results.ResultsMainLive do
  use BeamWeb, :live_view
  alias Beam.Accounts
  alias Beam.Exercices

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if current_user.type == "Paciente" do
      {:ok, push_navigate(socket, to: ~p"/results/per_user")}
    else
      patients = Accounts.list_patients_for_therapist(current_user.id)
      tasks = Exercices.list_tasks()

      {:ok,
       assign(socket, show_modal: false, show_task_modal: false, patients: patients, tasks: tasks)}
    end
  end

  def handle_event("open_modal", _params, socket) do
    {:noreply, assign(socket, show_modal: true)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_modal: false)}
  end

  def handle_event("open_task_modal", _params, socket) do
    {:noreply, assign(socket, show_task_modal: true)}
  end

  def handle_event("close_task_modal", _params, socket) do
    {:noreply, assign(socket, show_task_modal: false)}
  end

  def handle_event("select_patient", %{"patient_id" => patient_id}, socket) do
    case Accounts.get_user_id_by_patient_id(patient_id) do
      nil ->
        {:noreply, socket}

      user_id ->
        {:noreply, push_navigate(socket, to: ~p"/results/per_user?user_id=#{user_id}")}
    end
  end

  def handle_event("select_task", %{"task_id" => task_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/results/per_exercise?task_id=#{task_id}")}
  end

  def render(assigns) do
    ~H"""
    <div class="p-10 text-center">
      <h1 class="text-3xl font-bold mb-6">Resultados</h1>
      <div class="space-y-4">
        <button phx-click="open_modal" class="px-4 py-2 bg-blue-500 text-white rounded">
          Ver Resultados por Utilizador
        </button>
        <button phx-click="open_task_modal" class="px-4 py-2 bg-green-500 text-white rounded">
          Ver Resultados por Exercício
        </button>
      </div>

      <%= if @show_modal do %>
        <div class="fixed inset-0 flex items-center justify-center bg-gray-900 bg-opacity-50">
          <div class="bg-white p-6 rounded shadow-lg">
            <h2 class="text-xl font-bold mb-4">Selecionar Utilizador</h2>
            <form phx-submit="select_patient">
              <select name="patient_id" class="border p-2 rounded w-full">
                <%= for patient <- @patients do %>
                  <option value={patient.id}>{patient.user.name}</option>
                <% end %>
              </select>
              <div class="mt-4 flex justify-end space-x-2">
                <button type="submit" class="px-4 py-2 bg-blue-500 text-white rounded">
                  Selecionar
                </button>
                <button type="button" phx-click="close_modal" class="px-4 py-2 bg-gray-300 rounded">
                  Cancelar
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <%= if @show_task_modal do %>
        <div class="fixed inset-0 flex items-center justify-center bg-gray-900 bg-opacity-50">
          <div class="bg-white p-6 rounded shadow-lg">
            <h2 class="text-xl font-bold mb-4">Selecionar Exercício</h2>
            <form phx-submit="select_task">
              <select name="task_id" class="border p-2 rounded w-full">
                <%= for task <- @tasks do %>
                  <option value={task.id}>{task.name}</option>
                <% end %>
              </select>
              <div class="mt-4 flex justify-end space-x-2">
                <button type="submit" class="px-4 py-2 bg-green-500 text-white rounded">
                  Selecionar
                </button>
                <button
                  type="button"
                  phx-click="close_task_modal"
                  class="px-4 py-2 bg-gray-300 rounded"
                >
                  Cancelar
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end

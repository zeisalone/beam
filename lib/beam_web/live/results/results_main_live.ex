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
       assign(socket, show_modal: false, full_screen?: false, show_task_modal: false, patients: patients, tasks: tasks, open_help: false)}
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

  def handle_event("toggle_help", _, socket) do
    {:noreply, update(socket, :open_help, fn open -> !open end)}
  end

  def render(assigns) do
    ~H"""
    <div class="p-10 text-center">
      <div class="mx-auto max-w-md bg-white border border-gray-300 rounded-xl shadow-lg p-6">
      <h2 class="text-3xl font-bold mb-6">Resultados</h2>
        <div class="flex flex-col space-y-4 items-center">
          <.link navigate={~p"/results/general"} class="w-full rounded-lg bg-black hover:bg-blue-900 py-2 px-3 text-sm font-semibold leading-6 text-white active:text-white/80">
            Ver Estatísticas Gerais
          </.link>
          <.button phx-click="open_modal" class="w-full">
            Ver Resultados por Utilizador
          </.button>
          <.button phx-click="open_task_modal" class="w-full">
            Ver Resultados por Exercício
          </.button>
        </div>
      </div>

      <%= if @show_modal do %>
        <div class="fixed inset-0 flex items-center justify-center bg-gray-900 bg-opacity-50 z-50">
          <div class="bg-white p-6 rounded shadow-lg">
            <h2 class="text-xl font-bold mb-4">Selecionar Utilizador</h2>
            <form phx-submit="select_patient">
              <select name="patient_id" class="border p-2 rounded w-full">
                <%= for patient <- @patients do %>
                  <option value={patient.id}>{patient.user.name}</option>
                <% end %>
              </select>
              <div class="mt-4 flex justify-end space-x-2">
                <.button type="submit">Selecionar</.button>
                <.button type="button" phx-click="close_modal" class="bg-red-600 text-black hover:bg-red-700">
                  Cancelar
                </.button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <%= if @show_task_modal do %>
        <div class="fixed inset-0 flex items-center justify-center bg-gray-900 bg-opacity-50 z-50">
          <div class="bg-white p-6 rounded shadow-lg">
            <h2 class="text-xl font-bold mb-4">Selecionar Exercício</h2>
            <form phx-submit="select_task">
              <select name="task_id" class="border p-2 rounded w-full">
                <%= for task <- @tasks do %>
                  <option value={task.id}>{task.name}</option>
                <% end %>
              </select>
              <div class="mt-4 flex justify-end space-x-2">
                <.button type="submit">Selecionar</.button>
                <.button type="button" phx-click="close_task_modal" class="bg-red-600 text-black hover:bg-red-700">
                  Cancelar
                </.button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <.help_button open={@open_help}>
        <:help>
          <p><strong>1.</strong> Nesta página podes consultar os resultados de pacientes ou de exercícios realizados na aplicação.</p>
        </:help>
        <:help>
          <p><strong>2.</strong> O botão <em>Ver Resultados por Utilizador</em> permite-te escolher um paciente e ver o desempenho dele.</p>
        </:help>
        <:help>
          <p><strong>3.</strong> O botão <em>Ver Resultados por Exercício</em> mostra-te o desempenho agregado por tarefa.</p>
        </:help>
        <:help>
          <p><strong>4.</strong> Em ambos os modos, podes aplicar filtros para obter resultados mais detalhados.</p>
        </:help>
      </.help_button>
    </div>
    """
  end
end

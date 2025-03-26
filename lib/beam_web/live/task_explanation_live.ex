defmodule BeamWeb.TaskExplanationLive do
  use BeamWeb, :live_view
  alias Beam.Exercices
  alias Beam.Repo
  alias Beam.Accounts

  @impl true
  def mount(%{"task_id" => task_id}, _session, socket) do
    task = Repo.get!(Exercices.Task, task_id)
    current_user = socket.assigns.current_user

    if current_user.type == "Paciente" do
      Exercices.mark_recommendation_as_seen(task_id, current_user.id)
    end

    pacientes =
      if current_user.type == "Terapeuta" do
        Accounts.list_patients_for_therapist(current_user.id)
      else
        []
      end

    {:ok,
     assign(socket,
       task: task,
       pacientes: pacientes,
       show_dropdown: false,
       selected_patient: nil,
       show_difficulty: false,
       selected_difficulty: nil
     )}
  end

  @impl true
  def handle_event("toggle_dropdown", _params, socket) do
    {:noreply, assign(socket, show_dropdown: !socket.assigns.show_dropdown)}
  end

  @impl true
  def handle_event("select_patient", %{"patient_id" => patient_id}, socket) do
    {:noreply, assign(socket, selected_patient: patient_id)}
  end

  @impl true
  def handle_event("recommend_task", _params, socket) do
    case socket.assigns.selected_patient do
      nil ->
        {:noreply, put_flash(socket, :error, "Por favor, selecione um paciente.")}

      selected_patient_id when selected_patient_id != "" ->
        case Repo.get_by(Beam.Accounts.Therapist, user_id: socket.assigns.current_user.id) do
          nil ->
            {:noreply, put_flash(socket, :error, "Erro: Terapeuta não encontrado.")}

          therapist ->
            case Exercices.recommend_task(%{
                   task_id: socket.assigns.task.id,
                   patient_id: selected_patient_id,
                   therapist_id: therapist.therapist_id
                 }) do
              {:ok, _recommendation} ->
                {:noreply,
                 socket
                 |> put_flash(:info, "Tarefa recomendada com sucesso!")
                 |> assign(:show_dropdown, false)}

              {:error, reason} ->
                {:noreply,
                 put_flash(socket, :error, "Erro ao recomendar tarefa: #{inspect(reason)}.")}
            end
        end
    end
  end

  @impl true
  def handle_event("toggle_difficulty", _params, socket) do
    {:noreply, assign(socket, show_difficulty: !socket.assigns.show_difficulty)}
  end

  @impl true
  def handle_event("select_difficulty", %{"difficulty" => difficulty}, socket) do
    {:noreply, assign(socket, selected_difficulty: difficulty)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-9/10 bg-gray-200 p-6 shadow-md rounded-lg flex flex-col mt-8">
      <h1 class="text-2xl font-bold text-gray-800 text-center mb-4">
        {@task.name}
      </h1>

      <div class="justify-center flex space-x-4 mb-6">
        <.link navigate={~p"/tasks"}>
          <.button class="w-40">Voltar</.button>
        </.link>

        <%= if @current_user.type == "Paciente" do %>
          <div class="relative">
            <.button class="w-40 text-white" phx-click="toggle_difficulty">Começar Treino</.button>

            <%= if @show_difficulty do %>
              <div class="absolute bg-white border rounded-md shadow-md p-2 mt-2 w-48">
                <form phx-change="select_difficulty">
                  <select name="difficulty" class="block w-full p-2 border rounded-md text-gray-700">
                    <option value="">Escolha a dificuldade</option>
                    <option value="facil">Fácil</option>
                    <option value="medio">Médio</option>
                    <option value="dificil">Difícil</option>
                    <option value="criado">Criado</option>
                  </select>
                </form>

                <%= if @selected_difficulty do %>
                  <.link navigate={
                    ~p"/tasks/#{@task.id}/training?live_action=training&difficulty=#{@selected_difficulty}"
                  }>
                    <.button class="mt-2 w-full text-white p-2 rounded-md hover:bg-green-600">
                      Iniciar
                    </.button>
                  </.link>
                <% end %>
              </div>
            <% end %>
          </div>

          <.link navigate={~p"/tasks/#{@task.id}/test?live_action=test"}>
            <.button class="w-40 text-white">Começar Teste</.button>
          </.link>
        <% end %>

        <%= if @current_user.type == "Terapeuta" do %>
          <div class="relative">
            <.button class="w-40" phx-click="toggle_dropdown">Recomendar Tarefa</.button>

            <%= if @show_dropdown do %>
              <div class="absolute bg-white border rounded-md shadow-md p-2 mt-2 w-48">
                <form phx-change="select_patient">
                  <select
                    id="select-patient"
                    name="patient_id"
                    class="block w-full p-2 border rounded-md text-gray-700"
                  >
                    <option value="">Paciente</option>
                    <%= for paciente <- @pacientes do %>
                      <option value={paciente.patient_id}>{paciente.user.name}</option>
                    <% end %>
                  </select>
                </form>

                <button
                  phx-click="recommend_task"
                  phx-value-patient_id={@selected_patient}
                  class="mt-2 w-full bg-blue-500 text-white p-2 rounded-md hover:bg-blue-600"
                >
                  Confirmar
                </button>
              </div>
            <% end %>
          </div>
          <div class="relative">
            <.button class="w-40 text-white" phx-click="toggle_difficulty">Experimentar Tarefa</.button>
            <%= if @show_difficulty do %>
              <div class="absolute bg-white border rounded-md shadow-md p-2 mt-2 w-48">
                <form phx-change="select_difficulty">
                  <select name="difficulty" class="block w-full p-2 border rounded-md text-gray-700">
                    <option value="">Escolha a dificuldade</option>
                    <option value="facil">Fácil</option>
                    <option value="medio">Médio</option>
                    <option value="dificil">Difícil</option>
                    <option value="criado">Criado</option>
                  </select>
                </form>

                <%= if @selected_difficulty do %>
                  <.link navigate={
                    ~p"/tasks/#{@task.id}/training?live_action=training&difficulty=#{@selected_difficulty}"
                  }>
                    <.button class="mt-2 w-full text-white p-2 rounded-md hover:bg-green-600">
                      Iniciar
                    </.button>
                  </.link>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <textarea
        class="block w-full h-80 rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-400 bg-white p-3 resize-none overflow-auto"
        readonly
      >
          <%= @task.description %>
        </textarea>
    </div>
    """
  end
end

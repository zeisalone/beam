defmodule BeamWeb.TaskExplanationLive do
  use BeamWeb, :live_view
  alias Beam.Exercices
  alias Beam.Repo
  alias Beam.Accounts

  @impl true
  def mount(%{"task_id" => task_id}, _session, socket) do
    task = Repo.get!(Exercices.Task, task_id)
    current_user = socket.assigns.current_user

    recommendation =
      if current_user.type == "Paciente" do
        Exercices.get_oldest_unseen_recommendation(task.id, current_user.id)
      else
        nil
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
       selected_type: nil,
       full_screen?: false,
       open_help: false,
       selected_difficulty: nil,
       recommendation: recommendation
     )}
  end

  @impl true
  def handle_event("dismiss_recommendation", _params, socket) do
    Exercices.mark_recommendation_as_seen(socket.assigns.task.id, socket.assigns.current_user.id)
    {:noreply, assign(socket, recommendation: nil)}
  end

  def handle_event("start_task", %{"type" => "test"}, socket) do
    Exercices.mark_recommendation_as_seen(socket.assigns.task.id, socket.assigns.current_user.id)
    {:noreply, push_navigate(socket, to: ~p"/tasks/#{socket.assigns.task.id}/test?live_action=test")}
  end

  def handle_event("start_task", %{"type" => "training", "difficulty" => difficulty}, socket) do
    Exercices.mark_recommendation_as_seen(socket.assigns.task.id, socket.assigns.current_user.id)
    {:noreply, push_navigate(socket, to: ~p"/tasks/#{socket.assigns.task.id}/training?live_action=training&difficulty=#{difficulty}")}
  end

  def handle_event("toggle_dropdown", _params, socket) do
    {:noreply, assign(socket, show_dropdown: !socket.assigns.show_dropdown)}
  end

  def handle_event("select_patient", %{"patient_id" => patient_id}, socket) do
    {:noreply, assign(socket, selected_patient: patient_id)}
  end

  def handle_event("recommend_task", _params, socket) do
    case socket.assigns.selected_patient do
      nil ->
        {:noreply, put_flash(socket, :error, "Por favor, selecione um paciente.")}

      selected_patient_id when selected_patient_id != "" ->
        case Repo.get_by(Accounts.Therapist, user_id: socket.assigns.current_user.id) do
          nil ->
            {:noreply, put_flash(socket, :error, "Erro: Terapeuta não encontrado.")}

          therapist ->
            case Exercices.recommend_task(%{
                   task_id: socket.assigns.task.id,
                   patient_id: selected_patient_id,
                   therapist_id: therapist.therapist_id,
                   type: socket.assigns.selected_type,
                   difficulty: socket.assigns.selected_difficulty
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

  def handle_event("update_recommendation", params, socket) do
    {:noreply,
     assign(socket,
       selected_patient: Map.get(params, "patient_id", socket.assigns.selected_patient),
       selected_type: Map.get(params, "type", socket.assigns.selected_type),
       selected_difficulty: Map.get(params, "difficulty", socket.assigns.selected_difficulty)
     )}
  end

  def handle_event("toggle_difficulty", _params, socket) do
    {:noreply, assign(socket, show_difficulty: !socket.assigns.show_difficulty)}
  end

  def handle_event("select_difficulty", %{"difficulty" => difficulty}, socket) do
    {:noreply, assign(socket, selected_difficulty: difficulty)}
  end

  def handle_event("close_dropdown", _params, socket) do
    {:noreply, assign(socket, show_dropdown: false)}
  end

  def handle_event("close_difficulty", _params, socket) do
    {:noreply, assign(socket, show_difficulty: false)}
  end

  def handle_event("toggle_help", _, socket) do
    {:noreply, update(socket, :open_help, fn open -> !open end)}
  end

  def handle_event("select_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, selected_type: type)}
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
              <div class="absolute bg-white border rounded-md shadow-md p-2 mt-2 w-48" phx-click-away="close_difficulty">
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
              <div class="absolute bg-white border rounded-md shadow-md p-4 mt-2 w-64" phx-click-away="close_dropdown">
                <form phx-change="update_recommendation">
                  <select name="patient_id" class="block w-full p-2 border rounded-md mb-2">
                    <option value="">Escolha o paciente</option>
                    <%= for p <- @pacientes do %>
                      <option value={p.patient_id} selected={@selected_patient == p.patient_id}>
                        <%= p.user.name %>
                      </option>
                    <% end %>
                  </select>

                  <select name="type" class="block w-full p-2 border rounded-md mb-2">
                    <option value="">Tipo de exercício</option>
                    <option value="training" selected={@selected_type == "training"}>Treino</option>
                    <option value="test" selected={@selected_type == "test"}>Teste</option>
                  </select>

                  <%= if @selected_type == "training" do %>
                    <select name="difficulty" class="block w-full p-2 border rounded-md mb-2">
                      <option value="">Dificuldade</option>
                      <option value="facil" selected={@selected_difficulty == "facil"}>Fácil</option>
                      <option value="medio" selected={@selected_difficulty == "medio"}>Médio</option>
                      <option value="dificil" selected={@selected_difficulty == "dificil"}>Difícil</option>
                      <option value="criado" selected={@selected_difficulty == "criado"}>Criado</option>
                    </select>
                  <% end %>
                </form>

                <button
                  phx-click="recommend_task"
                  phx-value-patient_id={@selected_patient}
                  phx-value-type={@selected_type}
                  phx-value-difficulty={@selected_difficulty}
                  class="mt-4 w-full bg-blue-500 text-white p-2 rounded-md hover:bg-blue-600"
                >
                  Confirmar
                </button>
              </div>
            <% end %>
          </div>
          <div class="relative">
            <.button class="w-40 text-white" phx-click="toggle_difficulty">Experimentar Tarefa</.button>
            <%= if @show_difficulty do %>
              <div class="absolute bg-white border rounded-md shadow-md p-2 mt-2 w-48" phx-click-away="close_difficulty">
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

      <%= if @recommendation do %>
        <div class="bg-white border border-blue-300 rounded-md p-4 mb-6 shadow-md">
          <p class="mb-2 text-gray-700">
            <strong>O Terapeuta <%= @recommendation.therapist.user.name %></strong> recomenda que faças este exercício em modo
            <strong><%= @recommendation.type %></strong>
            <%= if @recommendation.difficulty do %>
              com dificuldade <strong><%= @recommendation.difficulty %></strong>
            <% end %>.
          </p>
          <div class="flex gap-4 mt-3">
            <.button phx-click="dismiss_recommendation" class="bg-gray-400 hover:bg-gray-500 text-white">
              Não começar e limpar
            </.button>

            <%= if @recommendation.type == :teste do %>
              <.button phx-click="start_task" phx-value-type="test" class="bg-blue-600 hover:bg-blue-700 text-white">
                Começar
              </.button>
            <% else %>
              <.button phx-click="start_task" phx-value-type="training" phx-value-difficulty={@recommendation.difficulty} class="bg-blue-600 hover:bg-blue-700 text-white">
                Começar
              </.button>
            <% end %>
          </div>
        </div>
      <% end %>

      <textarea
        class="block w-full whitespace-pre-line h-80 rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-400 bg-white p-3 resize-none overflow-auto"
        readonly
      >
          <%= @task.description %>
        </textarea>
    </div>
    <.help_button open={@open_help}>
      <:help>
        <p><strong>1.</strong> Esta página é a pagina relativa aos exercicios da aplicação.</p>
      </:help>

      <:help>
        <p><strong>2.</strong> Lê a descrição com atenção antes de fazeres o exercicio pela primeira vez.</p>
      </:help>

      <:help :if={@current_user.type == "Paciente"}>
        <p><strong>3.</strong> No botão <em>Começar Treino</em>, podes iniciar a tarefa em modo treino escolhendo a dificuldade que preferires, ou aquela que o teu terapeuta recomendar.</p>
      </:help>

      <:help :if={@current_user.type == "Paciente"}>
        <p><strong>4.</strong> No botão <em>Começar Teste</em>, irás realizar a tarefa em modo teste.</p>
      </:help>

      <:help :if={@current_user.type == "Terapeuta"}>
        <p><strong>3.</strong> No botão <em>Experimentar Tarefa</em> podes testar a tarefa em diferentes dificuldades.</p>
      </:help>

      <:help :if={@current_user.type == "Terapeuta"}>
        <p><strong>4.</strong> No botão <em>Recomendar Tarefa</em> podes recomendar esta tarefa a um dos teus pacientes.</p>
      </:help>
    </.help_button>
    """
  end
end

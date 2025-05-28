defmodule BeamWeb.ExerciseConfig.EditionsReserveLive do
  alias BeamWeb.ExerciseConfig.Labels
  use BeamWeb, :live_view

  alias Beam.Exercices
  alias Beam.Accounts
  alias Labels

  def mount(params, _session, socket) do
    current_user = socket.assigns.current_user
    task_id = Map.get(params, "task_id")

    all_configs = Exercices.list_visible_exercise_configurations_with_task()

    configs =
      case task_id do
        nil -> all_configs
        id -> Enum.filter(all_configs, &("#{&1.task_id}" == id))
      end

    pacientes =
      if current_user.type == "Terapeuta" do
        Accounts.list_patients_for_therapist(current_user.id)
      else
        []
      end

    access_map =
      for config <- configs, into: %{} do
        {config.id, Exercices.list_configuration_accesses_for_config(config.id)}
      end

    {:ok,
     assign(socket,
       configs: configs,
       pacientes: pacientes,
       current_user: current_user,
       active_config_id: nil,
       open_help: false,
       selected_config: nil,
       selected_config_for_recommendation: nil,
       selected_config_for_access: nil,
       full_screen?: false,
       task_id: task_id,
       access_map: access_map
     )}
  end

  def handle_event("open_patient_select", %{"config_id" => config_id}, socket) do
    config = Enum.find(socket.assigns.configs, &("#{&1.id}" == config_id))
    {:noreply, assign(socket, active_config_id: config_id, selected_config_for_recommendation: config)}
  end

  def handle_event("open_access_select", %{"config_id" => config_id}, socket) do
    config = Enum.find(socket.assigns.configs, &("#{&1.id}" == config_id))
    {:noreply, assign(socket, selected_config_for_access: config)}
  end

  def handle_event("close_access_select", _params, socket) do
    {:noreply, assign(socket, selected_config_for_access: nil)}
  end

  def handle_event("cancel_recommendation", _params, socket) do
    {:noreply, assign(socket, active_config_id: nil, selected_config_for_recommendation: nil)}
  end

  def handle_event("recommend_config", %{"config_id" => config_id, "patient_id" => patient_id}, socket) do
    current_user = socket.assigns.current_user

    cond do
      is_nil(patient_id) or patient_id == "" ->
        {:noreply, put_flash(socket, :error, "Por favor, selecione um paciente.")}

      true ->
        case Beam.Repo.get_by(Accounts.Therapist, user_id: current_user.id) do
          nil ->
            {:noreply, put_flash(socket, :error, "Erro: terapeuta não encontrado.")}

          therapist ->
            case Exercices.recommend_custom_configuration(%{
                   config_id: config_id,
                   patient_id: patient_id,
                   therapist_id: therapist.therapist_id
                 }) do
              {:ok, _} ->
                {:noreply,
                 socket
                 |> put_flash(:info, "Configuração recomendada com sucesso!")
                 |> assign(active_config_id: nil, selected_config_for_recommendation: nil)}

              {:error, reason} ->
                {:noreply, put_flash(socket, :error, "Erro ao recomendar: #{inspect(reason)}")}
            end
        end
    end
  end

  def handle_event("toggle_access", %{"config_id" => config_id, "patient_id" => patient_id}, socket) do
    config_id = String.to_integer(config_id)

    case Exercices.remove_exercise_configuration_access(config_id, patient_id) do
      {:error, :not_found} -> Exercices.add_exercise_configuration_access(%{configuration_id: config_id, patient_id: patient_id})
      _ -> :ok
    end

    updated = Exercices.list_configuration_accesses_for_config(config_id)
    {:noreply, update(socket, :access_map, &Map.put(&1, config_id, updated))}
  end

  def handle_event("open_details", %{"config_id" => id}, socket) do
    config = Enum.find(socket.assigns.configs, &("#{&1.id}" == id))
    {:noreply, assign(socket, selected_config: config)}
  end

  def handle_event("close_details", _params, socket) do
    {:noreply, assign(socket, selected_config: nil)}
  end

  def handle_event("hide_config", %{"config_id" => config_id}, socket) do
    case Exercices.hide_exercise_configuration(config_id) do
      {:ok, _} ->
        updated = Exercices.list_visible_exercise_configurations_with_task()
        filtered =
          case socket.assigns.task_id do
            nil -> updated
            id -> Enum.filter(updated, &("#{&1.task_id}" == id))
          end
        {:noreply, assign(socket, configs: filtered)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao esconder configuração.")}
    end
  end

  def handle_event("toggle_help", _, socket) do
    {:noreply, update(socket, :open_help, fn open -> !open end)}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-screen-lg mx-auto">
      <.header>Configurações Guardadas</.header>

      <div class="mt-6 overflow-auto rounded-lg border border-gray-200">
        <table class="w-full text-sm table-fixed">
          <thead>
            <tr class="bg-primary-50">
              <th class="w-1/4 px-4 py-3 text-left font-semibold">Nome</th>
              <th class="w-1/4 px-4 py-3 text-left font-semibold">Ações</th>
            </tr>
          </thead>
          <tbody>
            <%= for config <- @configs do %>
              <tr class="border-t border-gray-200 hover:bg-gray-50 transition-colors">
                <td class="px-4 py-3 font-medium truncate">
                  <div class="flex items-center gap-2">
                    <%= config.name %>
                    <button
                      type="button"
                      phx-click="hide_config"
                      phx-value-config_id={config.id}
                      data-confirm="Tem a certeza que quer apagar esta configuração?"
                      class="text-red-600 hover:text-red-800"
                    >
                      <img src="/images/trash.svg" alt="Apagar" class="h-4 w-4" />
                    </button>
                  </div>
                </td>
                <td class="px-4 py-3 text-blue-600 text-sm">
                  <div class="flex gap-4">
                    <%= if @current_user.type == "Terapeuta" do %>
                      <button
                        phx-click="open_patient_select"
                        phx-value-config_id={config.id}
                        class="hover:underline text-blue-600"
                      >
                        Recomendar
                      </button>
                      <button
                        phx-click="open_access_select"
                        phx-value-config_id={config.id}
                        class="hover:underline text-blue-600"
                      >
                        Pacientes
                      </button>
                    <% end %>

                    <button
                      phx-click="open_details"
                      phx-value-config_id={config.id}
                      class="hover:underline text-blue-600"
                    >
                      Ver detalhes
                    </button>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%= if @selected_config do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 z-40 flex items-center justify-center">
          <div class="bg-white rounded-lg p-6 w-full max-w-md shadow-lg relative z-50">
            <h2 class="text-xl font-semibold mb-4">Detalhes da Configuração</h2>

            <div class="max-h-96 overflow-y-auto text-sm">
              <%= for {key, val} <- @selected_config.data do %>
                <div class="mb-2">
                  <span class="font-semibold"><%= Labels.label_for(key) %>:</span>
                  <span><%= inspect(val) %></span>
                </div>
              <% end %>
            </div>

            <div class="mt-4 text-right">
              <.button phx-click="close_details" class="bg-red-500 hover:bg-red-600 text-white">
                Fechar
              </.button>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @selected_config_for_access do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 z-40 flex items-center justify-center">
          <div class="bg-white rounded-lg p-6 w-full max-w-md shadow-lg relative z-50">
            <h2 class="text-xl font-semibold mb-4">Acesso permanente</h2>
            <div class="text-sm space-y-2">
              <%= for p <- @pacientes do %>
                <label class="flex items-center gap-2">
                  <input type="checkbox"
                         phx-click="toggle_access"
                         phx-value-config_id={@selected_config_for_access.id}
                         phx-value-patient_id={p.patient_id}
                         checked={Enum.any?(@access_map[@selected_config_for_access.id] || [], &(&1.patient_id == p.patient_id))} />
                  <%= p.user.name %>
                </label>
              <% end %>
            </div>
            <div class="mt-4 text-right">
              <.button phx-click="close_access_select" class="bg-red-500 hover:bg-red-600 text-white">
                Fechar
              </.button>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @active_config_id && @selected_config_for_recommendation do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 z-40 flex items-center justify-center">
          <div class="bg-white rounded-lg p-6 w-full max-w-md shadow-lg relative z-50">
            <h2 class="text-xl font-semibold mb-4">Recomendar configuração</h2>

            <form phx-submit="recommend_config" class="flex flex-col gap-4">
              <input type="hidden" name="config_id" value={@selected_config_for_recommendation.id} />

              <select name="patient_id" class="rounded border px-2 py-2 text-sm">
                <option value="">Escolha o paciente</option>
                <%= for p <- @pacientes do %>
                  <option value={p.patient_id}><%= p.user.name %></option>
                <% end %>
              </select>

              <div class="flex justify-end gap-4">
                <button type="submit" class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded">
                  Confirmar
                </button>
                <button type="button" phx-click="cancel_recommendation" class="text-gray-600 hover:underline">
                  Cancelar
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    <.help_button open={@open_help}>
      <:help>
        <p><strong>1.</strong> Esta página permite visualizar todas as configurações personalizadas que criaste para tarefas da aplicação.</p>
      </:help>

      <:help>
        <p><strong>2.</strong> Podes <em>Recomendar</em> uma configuração diretamente a um paciente. Ela aparecerá como recomendação visível na interface dele.</p>
      </:help>

      <:help>
        <p><strong>3.</strong> Através do botão <em>Pacientes</em>, podes dar acesso permanente a uma configuração a qualquer paciente. Eles poderão utilizá-la quando quiserem, no modo treino, escolhendo a dificuldade <em>Criado</em>.</p>
      </:help>

      <:help>
        <p><strong>4.</strong> O botão <em>Ver detalhes</em> permite consultar os parâmetros específicos da configuração (tempo, número de rondas, tipo de pergunta, etc.).</p>
      </:help>

      <:help>
        <p><strong>5.</strong> Podes apagar uma configuração clicando no ícone da lata de lixo. Esta ação é permanente e remove o acesso para todos os pacientes.</p>
      </:help>
    </.help_button>
    """
  end
end

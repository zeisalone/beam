defmodule BeamWeb.DashboardLive do
  use BeamWeb, :live_view

  alias Beam.Accounts

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    all_pacientes =
      if current_user.type in ["Admin", "Terapeuta"], do: Accounts.list_pacientes(), else: []

    all_terapeutas = Accounts.list_terapeutas()

    {:ok,
     assign(socket,
       all_pacientes: all_pacientes,
       all_terapeutas: all_terapeutas,
       pacientes: all_pacientes,
       terapeutas: all_terapeutas,
       total_pacientes: length(all_pacientes),
       total_terapeutas: length(all_terapeutas),
       search_pacientes: "",
       search_terapeutas: "",
       only_mine: false,
       full_screen?: false,
       current_user: current_user
     )}
  end

  @impl true
  def handle_event("search_pacientes", %{"search" => search_term}, socket) do
    pacientes = filter_pacientes(socket.assigns.all_pacientes, search_term, socket.assigns.only_mine, socket.assigns.current_user)
    {:noreply, assign(socket, pacientes: pacientes, search_pacientes: search_term)}
  end

  def handle_event("toggle_only_mine", %{"only_mine" => only_mine_val}, socket) do
    only_mine = only_mine_val == "true"
    pacientes = filter_pacientes(socket.assigns.all_pacientes, socket.assigns.search_pacientes, only_mine, socket.assigns.current_user)
    {:noreply, assign(socket, pacientes: pacientes, only_mine: only_mine)}
  end

  @impl true
  def handle_event("search_terapeutas", %{"search" => search_term}, socket) do
    terapeutas_filtrados =
      socket.assigns.all_terapeutas
      |> Enum.filter(fn t ->
        String.contains?(String.downcase(t.user.name), String.downcase(search_term))
      end)

    terapeutas = if search_term == "", do: socket.assigns.all_terapeutas, else: terapeutas_filtrados

    {:noreply, assign(socket, terapeutas: terapeutas, search_terapeutas: search_term)}
  end

  defp filter_pacientes(all_pacientes, search_term, only_mine, current_user) do
    all_pacientes
    |> Enum.filter(fn p ->
      String.contains?(String.downcase(p.user.name), String.downcase(search_term || ""))
    end)
    |> Enum.filter(fn p ->
      not only_mine or (p.therapist.user.id == current_user.id)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dashboard content-center space-y-6">
      <div class="text-2xl text-center font-bold text-gray-800">
        Bem-vindo, {@current_user.type}!
      </div>

      <div class="flex content-center space-x-4 text-center justify-center">
        <%= if @current_user.type in ["Admin", "Terapeuta"] do %>
          <div class="border content-center border-gray-700 p-4 rounded-md text-center">
            <div class="font-bold text-gray-700">Total de Pacientes</div>
            <div class="text-3xl text-gray-800 mt-2">{@total_pacientes}</div>
          </div>
        <% end %>

        <div class="border content-center border-gray-700 p-4 rounded-md text-center">
          <div class="font-bold text-gray-700">Total de Terapeutas</div>
          <div class="text-3xl text-gray-800 mt-2">{@total_terapeutas}</div>
        </div>
      </div>

      <%= if @current_user.type in ["Admin", "Terapeuta"] do %>
        <div class="mt-8">
          <div class="text-lg font-bold text-gray-800 mb-1">Tabela de Pacientes</div>
          <.link navigate={~p"/dashboard/new_patient"} class="text-blue-500 hover:underline">
            Novo Paciente
          </.link>
        </div>
        <div class="flex items-center space-x-2 mb-2">
          <input
            type="checkbox"
            name="only_mine"
            id="only_mine"
            value="true"
            checked={@only_mine}
            phx-click="toggle_only_mine"
            phx-value-only_mine={to_string(!@only_mine)}
            class="h-4 w-4 text-blue-600 border-gray-300 rounded"
          />
          <label for="only_mine" class="text-sm text-gray-700">Apenas meus pacientes</label>
        </div>
        <div class="mt-3 mb-4 w-full">
          <form phx-change="search_pacientes" class="relative w-full max-w-4xl">
            <div class="flex items-center px-3 py-1 w-full">
              <img src="/images/search.svg" class="mr-2 h-4 w-4" />
              <input
                type="text"
                name="search"
                placeholder="Pesquisar pacientes..."
                class="w-full text-sm text-gray-700 placeholder-gray-400 bg-transparent focus:outline-none"
                value={@search_pacientes}
              />
            </div>
          </form>
        </div>

        <.table id="pacientes" rows={@pacientes}>
          <:col :let={paciente} label="Nome do Paciente">
            <.link navigate={~p"/dashboard/patient/#{paciente.user.id}"} class="hover:underline">
              {paciente.user.name}
            </.link>
          </:col>
          <:col :let={paciente} label="Email do Paciente">
            {paciente.user.email}
          </:col>
          <:col :let={paciente} label="Terapeuta Associado">
            {paciente.therapist.user.name}
          </:col>
        </.table>
      <% end %>

      <div class="mt-8">
        <div class="text-lg font-bold text-gray-800">Tabela de Terapeutas</div>

        <div class="mt-3 mb-4 w-full">
          <form phx-change="search_terapeutas" class="relative w-full max-w-4xl">
            <div class="flex items-center px-3 py-1 w-full">
              <img src="/images/search.svg" class="mr-2 h-4 w-4" />
              <input
                type="text"
                name="search"
                placeholder="Pesquisar terapeutas..."
                class="w-full text-sm text-gray-700 placeholder-gray-400 bg-transparent focus:outline-none"
                value={@search_terapeutas}
              />
            </div>
          </form>
        </div>


        <.table id="terapeutas" rows={@terapeutas}>
          <:col :let={terapeuta} label="Nome">
            {terapeuta.user.name}
          </:col>
          <:col :let={terapeuta} label="Email">
            {terapeuta.user.email}
          </:col>
        </.table>
      </div>
    </div>
    """
  end
end

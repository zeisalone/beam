defmodule BeamWeb.WelcomePageLive do
  use BeamWeb, :live_view

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    {:ok,
     assign(socket,
       full_screen?: false,
       user_name: current_user.name,
       open_help: false
     )}
  end

  def handle_event("toggle_help", _, socket) do
    {:noreply, update(socket, :open_help, fn open -> !open end)}
  end


  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center">
      <h1 class="text-4xl font-bold text-gray-900 mb-4 mt-6">Bem-vindo, {@user_name}!</h1>

      <div class="my-4">
        <img src="/images/BEAM1.png" alt="Beam Logo" class="w-96 h-96" />
      </div>

      <div class="flex space-x-4">
        <.link
          href={~p"/tasks"}
          class="relative inline-flex items-center justify-center p-0.5 overflow-hidden text-sm font-medium text-gray-900 rounded-lg group bg-gradient-to-br from-purple-500 to-pink-500 group-hover:from-purple-500 group-hover:to-pink-500 hover:text-white focus:ring-4 focus:outline-none focus:ring-purple-200"
        >
          <span class="relative px-6 py-3 transition-all ease-in duration-75 bg-white rounded-md group-hover:bg-transparent">
            Ver Tarefas
          </span>
        </.link>

        <.link
          href={~p"/results"}
          class="relative inline-flex items-center justify-center p-0.5 overflow-hidden text-sm font-medium text-gray-900 rounded-lg group bg-gradient-to-br from-pink-500 to-orange-400 group-hover:from-pink-500 group-hover:to-orange-400 hover:text-white focus:ring-4 focus:outline-none focus:ring-pink-200"
        >
          <span class="relative px-6 py-3 transition-all ease-in duration-75 bg-white rounded-md group-hover:bg-transparent">
            Ver Resultados
          </span>
        </.link>

        <.link
          href={~p"/users/profile"}
          class="relative inline-flex items-center justify-center p-0.5 overflow-hidden text-sm font-medium text-gray-900 rounded-lg group bg-gradient-to-br from-teal-300 to-lime-300 group-hover:from-teal-300 group-hover:to-lime-300 focus:ring-4 focus:outline-none focus:ring-lime-200"
        >
          <span class="relative px-6 py-3 transition-all ease-in duration-75 bg-white rounded-md group-hover:bg-transparent">
            Ver Perfil
          </span>
        </.link>
      </div>
    </div>
    <.help_button open={@open_help}>
      <:help>
        <p><strong>1.</strong> Bem-vindo ao BEAM! Este menu vai aparecer em algumas das páginas para te ajudar e dar dicas.</p>
      </:help>
      <:help>
        <p><strong>2.</strong> O Header acima estará presente ao longo da aplicação e é a principal forma de navegação da mesma.</p>
      </:help>

      <:help :if={@current_user.type == "Paciente"}>
        <p><strong>3.</strong> No botão <em>Ver Tarefas</em> podes aceder às atividades disponíveis para treinar.</p>
      </:help>
      <:help :if={@current_user.type == "Paciente"}>
        <p><strong>4.</strong> Em <em>Ver Resultados</em> podes consultar o teu desempenho.</p>
      </:help>
      <:help :if={@current_user.type == "Paciente"}>
        <p><strong>5.</strong> Em <em>Ver Perfil</em> podes alterar informações pessoais como a tua imagem ou palavra-passe.</p>
      </:help>

      <:help :if={@current_user.type == "Terapeuta"}>
        <p><strong>3.</strong> Em <em>Ver Tarefas</em> podes experimentar as atividades disponíveis ou preparar testes.</p>
      </:help>
      <:help :if={@current_user.type == "Terapeuta"}>
        <p><strong>4.</strong> Em <em>Ver Resultados</em> tens acesso às estatísticas dos teus pacientes.</p>
      </:help>
      <:help :if={@current_user.type == "Terapeuta"}>
        <p><strong>5.</strong> Em <em>Ver Perfil</em> podes gerir os teus dados de utilizador.</p>
      </:help>
      <:help :if={@current_user.type == "Terapeuta"}>
        <p><strong>6.</strong> A Pagina <em>Dashboard</em> contém uma lista dos pacientes e dos terapeutas da aplicação. Também é lá que podes adicionar pacientes.</p>
      </:help>
    </.help_button>
    """
  end
end

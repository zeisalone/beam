defmodule BeamWeb.UserProfileLive do
  use BeamWeb, :live_view
  alias Beam.Accounts

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns[:current_user] do
      nil ->
        {:ok, push_navigate(socket, to: "/users/log_in")}

      %{} = current_user ->
        user = Accounts.get_user!(current_user.id)
        email = Accounts.get_patient_email(user.id)
        age = if user.type == "Paciente", do: Accounts.get_patient_age(user.id), else: nil
        education = if user.type == "Paciente", do: Accounts.get_patient_education(user.id), else: nil
        gender = if user.type == "Paciente", do: Accounts.get_patient_gender(user.id), else: nil


        {:ok,
         assign(socket,
           current_user: user,
           email: email,
           full_screen?: false,
           age: age,
           gender: gender,
           education: education,
           open_help: false
         )}
    end
  end

  @impl true
  def handle_event("toggle_help", _, socket) do
    {:noreply, update(socket, :open_help, fn open -> !open end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-md mx-auto mt-10 bg-white shadow-xl rounded-lg text-gray-900">
      <div class="rounded-t-lg h-32 overflow-hidden">
        <img class="object-cover object-top w-full" src="/images/profile/ProfileHeader.png" alt="Header">
      </div>

      <div class="mx-auto w-28 h-28 relative -mt-14 border-4 border-white rounded-full overflow-hidden flex items-center justify-center bg-white">
        <img class="object-cover object-center h-24 w-24"
             src={Path.join("/", @current_user.profile_image || "images/profile/profile.svg")}
             alt="Profile Picture" />
      </div>

      <div class="text-center mt-2">
        <h2 class="font-semibold text-xl"><%= @current_user.name %></h2>
        <p class="text-gray-500 text-sm"><%= @current_user.type %></p>
      </div>

      <div class="py-4 mt-2 text-gray-700 flex items-center justify-center space-x-6">
        <div class="flex items-center space-x-2">
          <img src="/images/profile/email.svg" class="w-5 h-5" alt="Email Icon">
          <p><%= @email %></p>
        </div>

        <%= if @current_user.type == "Paciente" do %>
          <div class="flex items-center space-x-2">
            <img src="/images/profile/cake.svg" class="w-5 h-5" alt="Cake Icon">
            <p><%= @age %> anos</p>
          </div>
        <% end %>
      </div>

      <%= if @current_user.type == "Paciente" do %>
        <div class="flex items-center justify-center space-x-6 text-gray-700 mt-2">
          <div class="flex items-center space-x-2">
            <img src="/images/profile/gender.svg" class="w-5 h-5" alt="Gender Icon">
            <p><%= @gender %></p>
          </div>

          <div class="flex items-center space-x-2">
            <img src="/images/profile/school.svg" class="w-5 h-5" alt="School Icon">
            <p><%= @education %></p>
          </div>
        </div>
      <% end %>

      <div class="p-4 border-t mx-8 mt-2">
        <div class="flex justify-center space-x-4">
          <%= if @current_user.type == "Terapeuta" do %>
            <.link navigate={~p"/dashboard"} class="px-5 py-2 text-sm rounded-lg bg-gray-900 text-white font-semibold hover:shadow-lg">
              Ver Pacientes
            </.link>
          <% end %>

          <.link navigate={~p"/users/settings"} class="px-5 py-2 text-sm rounded-lg bg-gray-900 text-white font-semibold hover:shadow-lg">
            Editar Perfil
          </.link>

          <.link navigate={~p"/results"} class="px-5 py-2 text-sm rounded-lg bg-gray-900 text-white font-semibold hover:shadow-lg">
            Ver Resultados
          </.link>
        </div>
      </div>
    </div>

    <.help_button open={@open_help}>
      <:help>
        <p><strong>1.</strong> Esta é a tua página de perfil. Aqui podes ver e editar as tuas informações.</p>
      </:help>

      <:help>
        <p><strong>2.</strong> No botão <em>Editar Perfil</em> podes alterar dados como o nome, imagem de perfil ou palavra-passe.</p>
      </:help>

      <:help :if={@current_user.type == "Paciente"}>
        <p><strong>3.</strong> O botão <em>Ver Resultados</em> permite-te consultar o teu desempenho nas atividades.</p>
      </:help>

      <:help :if={@current_user.type == "Terapeuta"}>
        <p><strong>3.</strong> O botão <em>Ver Resultados</em> leva-te para a página com os resultados dos teus pacientes.</p>
      </:help>

      <:help :if={@current_user.type == "Terapeuta"}>
        <p><strong>4.</strong> O botão <em>Ver Pacientes</em> permite-te aceder à dashboard com a lista completa de pacientes.</p>
      </:help>
    </.help_button>
    """
  end
end

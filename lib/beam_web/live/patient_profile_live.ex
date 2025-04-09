defmodule BeamWeb.PatientProfileLive do
  use BeamWeb, :live_view
  alias Beam.Accounts

  @impl true
  def mount(%{"patient_id" => patient_id}, _session, socket) do
    case Accounts.get_patient_with_user(patient_id) do
      nil ->
        {:ok, push_navigate(socket, to: "/dashboard")}

      %{user: user} = patient ->
        full_user = Accounts.get_user!(user.id)
        age = Accounts.get_patient_age(full_user.id)
        email = Accounts.get_patient_email(full_user.id)

        {:ok,
         assign(socket,
           patient: %{patient | user: full_user},
           user_id: full_user.id,
           patient_id: patient.id,
           age: age,
           full_screen?: false,
           open_help: false,
           email: email
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
             src={Path.join("/", @patient.user.profile_image || "images/profile/profile.svg")}
             alt="Profile Picture" />
      </div>

      <div class="text-center mt-2">
        <h2 class="font-semibold text-xl"><%= @patient.user.name %></h2>
        <p class="text-gray-500 text-sm">Paciente</p>
      </div>

      <div class="py-4 mt-2 text-gray-700 flex items-center justify-center space-x-6">
        <div class="flex items-center space-x-2">
          <img src="/images/profile/email.svg" class="w-5 h-5" alt="Email Icon">
          <p><%= @email %></p>
        </div>

        <div class="flex items-center space-x-2">
          <img src="/images/profile/cake.svg" class="w-5 h-5" alt="Cake Icon">
          <p><%= @age %> anos</p>
        </div>
      </div>

      <div class="p-4 border-t mx-8 mt-2">
        <div class="flex justify-center space-x-4">
          <.link navigate={~p"/results/per_user?user_id=#{@patient.user.id}"} class="px-6 py-2 rounded-lg bg-gray-900 text-white font-semibold hover:shadow-lg">
            Ver Resultados
          </.link>

          <.link navigate={~p"/notes/#{@patient.user.id}"} class="px-6 py-2 rounded-lg bg-gray-900 text-white font-semibold hover:shadow-lg">
            Notas
          </.link>
        </div>
      </div>
    </div>
    <.help_button open={@open_help}>
        <:help>
          <p><strong>1.</strong> Neste menu podes aceder diretamente aos resultados deste paciente.</p>
        </:help>
        <:help>
          <p><strong>2.</strong> Com recurso ao botão <em>Notas</em> poderás adicionar notas para registar o progresso deste paciente.</p>
        </:help>
      </.help_button>
    """
  end
end

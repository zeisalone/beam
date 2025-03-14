defmodule BeamWeb.PatientProfileLive do
  use BeamWeb, :live_view
  alias Beam.Accounts

  def mount(%{"patient_id" => patient_id}, _session, socket) do
    case Accounts.get_patient_with_user(patient_id) do
      nil ->
        {:ok, push_navigate(socket, to: "/dashboard")}

      patient ->
        user_id = patient.user.id
        {:ok, assign(socket, patient: patient, user_id: user_id, patient_id: patient.id)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center h-96 bg-gray-300 p-6 mt-12 rounded-lg">
      <img
        src={"/" <> (@patient.user.profile_image || "images/profile/profile.svg")}
        alt="Profile Picture"
        class="w-24 h-24 rounded-full mx-auto mb-4 border-2 border-gray-300"
      />
      <h1 class="text-xl font-bold text-gray-900">{@patient.user.name}</h1>

      <div class="flex justify-center space-x-4 mt-6">
        <.link
          navigate={~p"/results/per_user?user_id=#{@patient.user.id}"}
          class="border border-gray-500 px-4 py-2 rounded hover:bg-gray-200"
        >
          Ver Resultados do Paciente
        </.link>

        <.link
          navigate={~p"/notes/#{@patient.user.id}"}
          class="border border-gray-500 px-4 py-2 rounded"
        >
          Notas
        </.link>
      </div>
    </div>
    """
  end
end

defmodule BeamWeb.UserProfileLive do
  use BeamWeb, :live_view

  def mount(_params, _session, socket) do
    if socket.assigns[:current_user] do
      {:ok, socket}
    else
      {:ok, push_navigate(socket, to: "/users/log_in")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center h-96 bg-gray-300 p-6 mt-12 rounded-lg">
      <img
        src={"/" <> (@current_user.profile_image || "images/profile/profile.svg")}
        alt="Profile Picture"
        class="w-24 h-24 rounded-full mx-auto mb-4 border-2 border-gray-300"
      />
      <h1 class="text-xl font-bold text-gray-900">{@current_user.name}</h1>

      <div class="flex justify-center space-x-4 mt-6">
        <%= if @current_user.type == "Terapeuta" do %>
          <.link navigate={~p"/dashboard"} class="border border-gray-500 px-4 py-2 rounded">
            Ver Lista de Pacientes
          </.link>
        <% end %>

        <.link navigate={~p"/users/settings"} class="border border-gray-500 px-4 py-2 rounded">
          Editar Perfil
        </.link>

        <.link
          navigate={~p"/results"}
          class="border border-gray-500 px-4 py-2 rounded hover:bg-gray-200"
        >
          Ver Resultados
        </.link>
      </div>
    </div>
    """
  end
end

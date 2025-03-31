defmodule BeamWeb.UserLoginLive do
  use BeamWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Iniciar sessão na conta
        <:subtitle>
          Não tem uma conta?
          <.link navigate={~p"/users/register"} class="font-semibold text-brand hover:underline">
            Registe-se
          </.link>
          para criar uma agora.
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="login_form"
        action={~p"/users/log_in"}
        phx-change="update_form"
      >
        <.input field={@form[:email]} type="email" label="Email" required />

        <div class="relative">
          <.input
            field={@form[:password]}
            type={if @show_password, do: "text", else: "password"}
            label="Palavra-passe"
            required
            class="pr-10"
          />
          <button
            type="button"
            phx-click="toggle_password_visibility"
            class="absolute right-3 top-[38px] flex items-center justify-center"
            aria-label="Alternar visibilidade da palavra-passe"
          >
            <img
              src={if @show_password, do: "/images/eye-slash.svg", else: "/images/eye.svg"}
              alt="Toggle password visibility"
              class="w-5 h-5 mt-1 opacity-70 hover:opacity-100"
            />
          </button>
        </div>

        <:actions>
          <.input field={@form[:remember_me]} type="checkbox" label="Manter-me autenticado" />
          <.link href={~p"/users/reset_password"} class="text-sm font-semibold">
            Perdeu a sua password?
          </.link>
        </:actions>
        <:actions>
          <.button phx-disable-with="A iniciar sessão..." class="w-full">
            Iniciar sessão <span aria-hidden="true">→</span>
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form, show_password: false)}
  end

  def handle_event("update_form", %{"user" => user_params}, socket) do
    form = to_form(user_params, as: "user")
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("toggle_password_visibility", _params, socket) do
    form = to_form(socket.assigns.form.params || %{}, as: "user")
    {:noreply, assign(socket, show_password: not socket.assigns.show_password, form: form)}
  end
end

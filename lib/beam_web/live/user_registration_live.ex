defmodule BeamWeb.UserRegistrationLive do
  use BeamWeb, :live_view

  alias Beam.Accounts
  alias Beam.Accounts.User

 def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Registar uma conta de Terapeuta
        <:subtitle>
          Já está registado?
          <.link navigate={~p"/users/log_in"} class="font-semibold text-brand hover:underline">
            Inicie sessão
          </.link>
          na sua conta agora.
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="registration_form"
        phx-submit="save"
        phx-change="validate"
        phx-trigger-action={@trigger_submit}
        action={~p"/users/log_in?_action=registered"}
        method="post"
      >
        <.error :if={@check_errors}>
          Oops, algo correu mal! Por favor, verifique os erros abaixo.
        </.error>

        <.input field={@form[:name]} type="text" label="Nome" required />
        <input type="hidden" name="user[type]" value="Terapeuta" />
        <.input field={@form[:email]} type="email" label="Email" required />
        <.input field={@form[:password]} type="password" label="Palavra-passe" required />
        <.input name="user[specialization_select]" type="select" label="Especialidade" value={@specialization_select} options={["Terapeuta", "Terapeuta Ocupacional", "Psicólogo", "Outro"]} required />
        <%= if @specialization_select == "Outro" do %>
          <.input name="user[specialization_other]" type="text" value={@specialization_other} maxlength="40" placeholder="Escreva a sua especialidade" required />
        <% end %>

        <:actions>
          <.button phx-disable-with="A criar conta..." class="w-full">Criar conta</.button>
        </:actions>
      </.simple_form>
      <%= if @user_created do %>
        <div class="mt-4 text-center">
          <p>Utilizador criado com sucesso!</p>
        </div>
      <% end %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(
        trigger_submit: false,
        check_errors: false,
        user_created: false,
        full_screen?: false,
        created_user: nil,
        specialization_select: "Terapeuta",
        specialization_other: ""
      )
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    specialization =
      case Map.get(user_params, "specialization_select", "Terapeuta") do
        "Outro" -> String.trim(Map.get(user_params, "specialization_other", "Terapeuta"))
        other   -> other
      end

    user_params = Map.put(user_params, "type", "Terapeuta")

    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        changeset = Accounts.change_user_registration(user)

        socket =
          socket
          |> assign(trigger_submit: true, user_created: true, created_user: user)
          |> assign_form(changeset)
        case Accounts.verify_user_type(user.id, nil, nil, nil, nil, specialization) do
          {:ok, :ok} ->
            {:noreply, socket}

          {:error, reason} ->
            {:noreply,
            socket
            |> put_flash(:error, "Erro ao verificar o tipo de utilizador: #{inspect(reason)}")
            |> assign(user_created: false)}
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("specialization_select", %{"user" => %{"specialization_select" => select}}, socket) do
    {:noreply, assign(socket, specialization_select: select)}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    specialization_select = Map.get(user_params, "specialization_select", "Terapeuta")
    specialization_other = Map.get(user_params, "specialization_other", "")

    socket =
      socket
      |> assign_form(Accounts.change_user_registration(%User{}, user_params))
      |> assign(
        specialization_select: specialization_select,
        specialization_other: specialization_other
      )
    {:noreply, Map.put(socket, :form, Map.put(socket.assigns.form, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end

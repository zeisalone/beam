defmodule BeamWeb.UserPatientCreationLive do
  use BeamWeb, :live_view

  alias Beam.Accounts
  alias Beam.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Criar Paciente
        <:subtitle>
          Preencha os detalhes abaixo para registar um novo paciente.
        </:subtitle>
      </.header>

      <.simple_form for={@form} id="patient_creation_form" phx-submit="save" phx-change="validate">
        <.input field={@form[:name]} type="text" label="Nome" required />
        <.input field={@form[:email]} type="email" label="Email" required />
        <.input field={@form[:password]} type="password" label="Palavra-passe" required />
        <.input field={@form[:type]} type="select" label="Tipo" options={["Paciente"]} required />
        <.input
          field={@form[:therapist_id]}
          type="select"
          label="Terapeuta Atribuído"
          options={Enum.map(@terapeutas, &{&1.user.name, &1.therapist_id})}
          required
        />
        <:actions>
          <.button phx-disable-with="A criar paciente..." class="w-full">Criar Paciente</.button>
        </:actions>
      </.simple_form>

      <%= if @patient_created do %>
        <div class="mt-4 text-center">
          <p>Paciente criado com sucesso!</p>
        </div>
      <% end %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    terapeutas = Accounts.list_terapeutas()
    changeset = Accounts.change_user_registration(%User{})
    form = to_form(changeset, as: "user")

    {:ok, assign(socket, terapeutas: terapeutas, form: form, patient_created: false)}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> Accounts.change_user_registration(user_params)
      |> Map.put(:action, :validate)

    form = to_form(changeset, as: "user")
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
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
          |> assign(trigger_submit: true, patient_created: true, created_user: user)
          |> assign_form(changeset)

        case Accounts.verify_user_type(user.id, user_params["therapist_id"]) do
          {:ok, :ok} ->
            # Adiciona o redirecionamento aqui
            {:noreply, push_navigate(socket, to: ~p"/dashboard")}

          {:error, reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Erro ao associar paciente ao terapeuta: #{inspect(reason)}")
             |> assign(patient_created: false)}
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
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

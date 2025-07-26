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
        <input type="hidden" name="user[type]" value="Paciente" />
        <.input field={@form[:email]} type="email" label="Email" required />
        <.input field={@form[:password]} type="password" label="Palavra-passe" required />
        <.input field={@form[:birth_date]} type="date" label="Data de Nascimento" required />
        <.input field={@form[:gender]} type="select" label="Género" options={["Masculino", "Feminino", "Outro"]} required />
        <.input field={@form[:education_level]} type="select" label="Escolaridade" options={["Pré-Primaria", "1º ciclo", "2º ciclo", "3º ciclo", "Secundário", "Universitário"]} required />
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

  def mount(_params, session, socket) do
    user_token = session["user_token"]
    current_user =
      if user_token do
        Beam.Accounts.get_user_by_session_token(user_token)
      else
        nil
      end

    therapist = if current_user, do: Accounts.get_therapist_by_user_id(current_user.id), else: nil

    if is_nil(current_user) or is_nil(therapist) do
      {:ok, push_navigate(socket, to: "/dashboard")}
    else
      changeset = Accounts.change_user_registration(%User{type: "Paciente"})
      socket =
        socket
        |> assign(
          therapist_id: therapist.therapist_id,
          form: to_form(changeset, as: "user"),
          check_errors: false,
          patient_created: false,
          full_screen?: false,
          created_user: nil
        )
      {:ok, socket, temporary_assigns: [form: nil]}
    end
  end


  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      Accounts.change_user_registration(%User{}, Map.put(user_params, "type", "Paciente"))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: "user"), check_errors: !changeset.valid?)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    user_params = Map.put(user_params, "type", "Paciente")
    therapist_id = socket.assigns.therapist_id

    case Date.from_iso8601(user_params["birth_date"]) do
      {:ok, birth_date} ->
        updated_params = Map.put(user_params, "birth_date", birth_date)
        gender = updated_params["gender"] || "Masculino"
        education_level = updated_params["education_level"] || "Pré-Primaria"

        case Accounts.register_user(updated_params) do
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

            case Accounts.verify_user_type(
                  user.id,
                  therapist_id,
                  birth_date,
                  gender,
                  education_level
                ) do
              {:ok, :ok} ->
                {:noreply, push_navigate(socket, to: ~p"/dashboard")}

              {:error, reason} ->
                {:noreply,
                 socket
                 |> put_flash(:error, "Erro ao associar paciente ao terapeuta: #{inspect(reason)}")
                 |> assign(patient_created: false)}
            end

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, check_errors: true, form: to_form(changeset, as: "user"))}
        end

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Formato de data inválido.")}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, form: to_form(changeset, as: "user"))
  end
end

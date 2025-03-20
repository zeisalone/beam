defmodule BeamWeb.UserSettingsLive do
  use BeamWeb, :live_view
  alias Beam.Accounts

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> assign(:selected_image, user.profile_image)
      |> assign(:birth_date, (if user.type == "Paciente", do: Accounts.get_patient_birth_date(user.id), else: nil))

    {:ok, socket}
  end

  def handle_event("select_image", %{"image" => image}, socket) do
    {:noreply, assign(socket, :selected_image, image)}
  end

  def handle_event("save_profile_image", _params, socket) do
    user = socket.assigns.current_user

    case Beam.Accounts.update_user(user, %{profile_image: socket.assigns.selected_image}) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_user, updated_user)
         |> put_flash(:info, "Imagem de perfil atualizada!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Erro ao atualizar a imagem de perfil.")}
    end
  end

  def handle_event("update_birth_date", %{"birth_date" => birth_date_string}, socket) do
    user = socket.assigns.current_user

    case Date.from_iso8601(birth_date_string) do
      {:ok, birth_date} ->
        case Accounts.update_patient_birth_date(user.id, birth_date) do
          {:ok, _updated_patient} ->
            {:noreply,
             socket
             |> assign(:birth_date, birth_date)
             |> put_flash(:info, "Data de nascimento atualizada!")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Erro ao atualizar a data de nascimento.")}
        end

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Formato de data inválido.")}
    end
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "Um link de confirmação foi enviado para o novo email."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Configurações da Conta
      <:subtitle>Gerencie seu email, palavra-passe, imagem de perfil e data de nascimento</:subtitle>
    </.header>

    <div class="flex justify-center space-x-4 mt-4">
      <button
        phx-click="select_image"
        phx-value-image="images/profile/profile.svg"
        class={"border p-2 rounded #{if @selected_image == "images/profile/profile.svg", do: "border-blue-500"}"}
      >
        <img src="/images/profile/profile.svg" class="w-24 h-24 mx-auto" />
      </button>

      <button
        phx-click="select_image"
        phx-value-image="images/profile/profile_female.svg"
        class={"border p-2 rounded #{if @selected_image == "images/profile/profile_female.svg", do: "border-blue-500"}"}
      >
        <img src="/images/profile/profile_female.svg" class="w-24 h-24 mx-auto" />
      </button>
    </div>

    <.button phx-click="save_profile_image" phx-disable-with="Salvando...">
      Salvar Imagem de Perfil
    </.button>

     <%= if @current_user.type == "Paciente" do %>
        <div>
          <h2 class="text-lg font-semibold mt-6">Data de Nascimento</h2>
          <form phx-submit="update_birth_date">
            <input
              type="date"
              name="birth_date"
              value={@birth_date}
              class="mt-2 border rounded p-2"
            />
            <button type="submit" class="ml-2 px-4 py-2 bg-gray-900 text-white rounded-lg font-semibold hover:shadow-lg">
              Salvar
            </button>
          </form>
        </div>
      <% end %>

    <div class="space-y-12 divide-y">
      <div>
        <.simple_form
          for={@email_form}
          id="email_form"
          phx-submit="update_email"
          phx-change="validate_email"
        >
          <.input field={@email_form[:email]} type="email" label="Email" required />
          <.input
            field={@email_form[:current_password]}
            name="current_password"
            id="current_password_for_email"
            type="password"
            label="Palavra-passe atual"
            value={@email_form_current_password}
            required
          />
          <:actions>
            <.button phx-disable-with="Alterando...">Alterar Email</.button>
          </:actions>
        </.simple_form>
      </div>

      <div>
        <.simple_form
          for={@password_form}
          id="password_form"
          action={~p"/users/log_in?_action=password_updated"}
          method="post"
          phx-change="validate_password"
          phx-submit="update_password"
          phx-trigger-action={@trigger_submit}
        >
          <input
            name={@password_form[:email].name}
            type="hidden"
            id="hidden_user_email"
            value={@current_email}
          />
          <.input
            field={@password_form[:password]}
            type="password"
            label="Nova palavra-passe"
            required
          />
          <.input
            field={@password_form[:password_confirmation]}
            type="password"
            label="Confirmar nova palavra-passe"
          />
          <.input
            field={@password_form[:current_password]}
            name="current_password"
            type="password"
            label="Palavra-passe atual"
            id="current_password_for_password"
            value={@current_password}
            required
          />
          <:actions>
            <.button phx-disable-with="Alterando...">Alterar Palavra-passe</.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end
end

defmodule BeamWeb.UserSettingsLive do
  use BeamWeb, :live_view
  alias Beam.Accounts

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    user = Beam.Accounts.get_user!(user_id)

    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)

    default_images = [
      "images/profile/profile.svg",
      "images/profile/profile_female.svg"
    ]

    custom_images =
      user.custom_images || []
      |> Enum.concat([user.profile_image | default_images])
      |> Enum.uniq()


    specialization_select =
      case user.type do
        "Terapeuta" ->
          therapist = Accounts.get_therapist_by_user_id(user.id)
          case therapist && therapist.specialization do
            "Terapeuta" -> "Terapeuta"
            "Terapeuta Ocupacional" -> "Terapeuta Ocupacional"
            "Psicólogo" -> "Psicólogo"
            val when is_binary(val) -> "Outro"
            _ -> "Terapeuta"
          end
        _ -> nil
      end

    specialization_other =
      case user.type do
        "Terapeuta" ->
          therapist = Accounts.get_therapist_by_user_id(user.id)
          spec = therapist && therapist.specialization
          if spec in ["Terapeuta", "Terapeuta Ocupacional", "Psicólogo"] or is_nil(spec), do: "", else: spec
        _ -> ""
      end

    socket =
      socket
      |> allow_upload(:profile_image, accept: ~w(.jpg .jpeg .png .svg), max_entries: 1, auto_upload: true)
      |> assign(:current_user, user)
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> assign(:selected_image, user.profile_image)
      |> assign(:birth_date, (if user.type == "Paciente", do: Accounts.get_patient_birth_date(user.id), else: nil))
      |> assign(:pending_image, nil)
      |> assign(:custom_images, custom_images)
      |> assign(:selected_image, user.profile_image)
      |> assign(:full_screen?, false)
      |> assign(:confirm_delete_image, nil)
      |> assign(:gender, (if user.type == "Paciente", do: Accounts.get_patient_gender(user.id), else: nil))
      |> assign(:education_level, (if user.type == "Paciente", do: Accounts.get_patient_education(user.id), else: nil))
      |> assign(:specialization_select, specialization_select)
      |> assign(:specialization_other, specialization_other)


    {:ok, socket}
  end

  def handle_event("select_image", %{"image" => image}, socket) do
    {:noreply, assign(socket, :selected_image, image)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :profile_image, ref)}
  end

  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("add_uploaded_image", _params, socket) do
    user = socket.assigns.current_user

    uploaded_files =
      consume_uploaded_entries(socket, :profile_image, fn %{path: path}, entry ->
        safe_name = Path.basename(entry.client_name) |> String.replace(~r/[^a-zA-Z0-9._-]/, "_")
        filename = "#{user.id}_#{System.system_time(:millisecond)}_#{safe_name}"
        dest = Path.join([:code.priv_dir(:beam), "static", "uploads", filename])

        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)

        {:ok, "/uploads/#{filename}"}
      end)

    case List.first(uploaded_files) do
      nil ->
        {:noreply, put_flash(socket, :error, "Nenhuma imagem selecionada.")}

      image_path ->
        updated_images = Enum.uniq([image_path | user.custom_images || []])

        case Beam.Accounts.update_user(user, %{
               custom_images: updated_images,
               profile_image: image_path
             }) do
          {:ok, updated_user} ->
            {:noreply,
             socket
             |> assign(:pending_image, nil)
             |> assign(:selected_image, image_path)
             |> assign(:custom_images, updated_images)
             |> assign(:current_user, updated_user)
             |> put_flash(:info, "Imagem adicionada!")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Erro ao guardar imagem.")}
        end
    end
  end

  def handle_event("save_profile_image", _params, socket) do
    user = socket.assigns.current_user
    selected = socket.assigns.selected_image
    default_images = [
      "images/profile/profile.svg",
      "images/profile/profile_female.svg"
    ]

    if selected in (socket.assigns.custom_images ++ default_images) do
      case Beam.Accounts.update_user(user, %{profile_image: selected}) do
        {:ok, updated_user} ->
          {:noreply,
          socket
          |> assign(:current_user, updated_user)
          |> put_flash(:info, "Imagem de perfil atualizada!")}
        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Erro ao atualizar a imagem de perfil.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Nenhuma imagem válida selecionada.")}
    end
  end

  def handle_event("delete_image", %{"image" => image}, socket) do
    user = socket.assigns.current_user
    updated_images = socket.assigns.custom_images |> Enum.reject(&(&1 == image))

    attrs = %{
      custom_images: updated_images
    }

    attrs =
      if user.profile_image == image do
        Map.put(attrs, :profile_image, "images/profile/profile.svg")
      else
        attrs
      end

      case Beam.Accounts.update_user(user, attrs) do
        {:ok, updated_user} ->
          {:noreply,
           socket
           |> assign(:custom_images, updated_images)
           |> assign(:current_user, updated_user)
           |> assign(:selected_image, updated_user.profile_image)
           |> assign(:confirm_delete_image, nil)
           |> put_flash(:info, "Imagem removida!")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Erro ao remover a imagem.")}
      end
  end

  def handle_event("confirm_delete_image", %{"image" => image}, socket) do
    {:noreply, assign(socket, :confirm_delete_image, image)}
  end

  def handle_event("cancel_delete_image", _params, socket) do
    {:noreply, assign(socket, :confirm_delete_image, nil)}
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

 def handle_event("update_gender", %{"gender" => gender}, socket) do
    user = socket.assigns.current_user

    case Accounts.update_patient_gender(user.id, gender) do
      {:ok, _} ->
        {:noreply, assign(socket, :gender, gender) |> put_flash(:info, "Género atualizado!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao atualizar género.")}
    end
  end

  def handle_event("update_education", %{"education_level" => education}, socket) do
    user = socket.assigns.current_user

    case Accounts.update_patient_education(user.id, education) do
      {:ok, _} ->
        {:noreply, assign(socket, :education_level, education) |> put_flash(:info, "Escolaridade atualizada!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao atualizar escolaridade.")}
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

  def handle_event("validate_specialization", params, socket) do
    spec_select = Map.get(params, "specialization_select", "Terapeuta")
    spec_other = Map.get(params, "specialization_other", "")
    {:noreply, assign(socket, specialization_select: spec_select, specialization_other: spec_other)}
  end

  def handle_event("update_specialization", params, socket) do
    spec =
      case Map.get(params, "specialization_select", "Terapeuta") do
        "Outro" -> String.trim(Map.get(params, "specialization_other", "Terapeuta"))
        val -> val
      end

    user = socket.assigns.current_user
    therapist = Accounts.get_therapist_by_user_id(user.id)

    case therapist do
      nil ->
        {:noreply, put_flash(socket, :error, "Terapeuta não encontrado.")}
      _ ->
        case Beam.Accounts.update_therapist_specialization(therapist, spec) do
          {:ok, _updated} ->
            {:noreply, put_flash(socket, :info, "Especialidade atualizada!")}
          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Erro ao atualizar especialidade.")}
        end
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

  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
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

      <%= for image <- @custom_images do %>
        <div class="relative">
          <button
            phx-click="select_image"
            phx-value-image={image}
            class={"border p-2 rounded #{if @selected_image == image, do: "border-blue-500"}"}
          >
            <img src={image} class="w-24 h-24 rounded-full object-cover" />
          </button>

          <button
            type="button"
            phx-click="confirm_delete_image"
            phx-value-image={image}
            class="absolute top-0 right-0 bg-red-600 text-white rounded-full w-5 h-5 text-xs hover:bg-red-700"
            title="Remover imagem"
          >
            ×
          </button>
        </div>
      <% end %>
    </div>

    <form phx-change="validate_upload" phx-submit="save_profile_image" enctype="multipart/form-data">
      <div class="flex items-center gap-4 mt-4">
        <.button type="submit" phx-disable-with="Salvando...">
          Salvar Imagem de Perfil
        </.button>

        <.live_file_input upload={@uploads.profile_image} />
      </div>

      <%= for entry <- @uploads.profile_image.entries do %>
        <div class="flex flex-col items-center">
          <.live_img_preview entry={entry} class="w-24 h-24 rounded-full border mt-4" />
          <progress value={entry.progress} max="100" class="w-full mt-2"></progress>

          <button
            type="button"
            phx-click="cancel-upload"
            phx-value-ref={entry.ref}
            class="mt-2 text-sm text-red-500 hover:underline"
          >
            Cancelar
          </button>
        </div>
      <% end %>

      <%= if Enum.any?(@uploads.profile_image.entries) do %>
        <div class="flex justify-center mt-4">
          <button
            type="button"
            phx-click="add_uploaded_image"
            class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            Adicionar imagem
          </button>
        </div>
      <% end %>
    </form>

    <%= if @current_user.type == "Paciente" do %>
      <div class="mt-6">
        <h2 class="text-lg font-semibold mb-2">Informações do Paciente</h2>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <form phx-submit="update_birth_date" class="flex flex-col">
            <label class="text-sm font-semibold mb-1">Data de Nascimento</label>
            <input
              type="date"
              name="birth_date"
              value={@birth_date}
              class="border border-gray-300 rounded p-2 focus:border-gray-400 focus:ring-0"
            />
            <button type="submit" class="mt-2 rounded-lg bg-black hover:bg-blue-900 py-2 px-3 text-sm font-semibold leading-6 text-white active:text-white/80">
              Salvar
            </button>
          </form>

          <form phx-submit="update_gender" class="flex flex-col">
            <label class="text-sm font-semibold mb-1">Género</label>
            <select name="gender" class="border border-gray-300 rounded p-2 focus:border-gray-400 focus:ring-0">
              <%= for g <- ["Masculino", "Feminino", "Outro"] do %>
                <option value={g} selected={@gender == g}><%= g %></option>
              <% end %>
            </select>
            <button type="submit" class="mt-2 rounded-lg bg-black hover:bg-blue-900 py-2 px-3 text-sm font-semibold leading-6 text-white active:text-white/80">
              Salvar
            </button>
          </form>

          <form phx-submit="update_education" class="flex flex-col">
            <label class="text-sm font-semibold mb-1">Escolaridade</label>
            <select name="education_level" class="border border-gray-300 rounded p-2 focus:border-gray-400 focus:ring-0">
              <%= for e <- ["Pré-Primaria", "1º ciclo", "2º ciclo", "3º ciclo", "Secundário", "Universitário"] do %>
                <option value={e} selected={@education_level == e}><%= e %></option>
              <% end %>
            </select>
            <button type="submit" class="mt-2 rounded-lg bg-black hover:bg-blue-900 py-2 px-3 text-sm font-semibold leading-6 text-white active:text-white/80">
              Salvar
            </button>
          </form>
        </div>
      </div>
    <% end %>

    <%= if @current_user.type == "Terapeuta" do %>
      <div class="mt-6 mb-10 max-w-sm mx-auto">
        <form phx-change="validate_specialization" phx-submit="update_specialization" class="flex flex-col max-w-xs gap-2">
          <label class="block font-semibold text-sm mb-1">Especialidade</label>
          <select name="specialization_select" value={@specialization_select} class="border border-gray-300 rounded p-2 focus:border-gray-400 focus:ring-0">
            <option value="Terapeuta" selected={@specialization_select == "Terapeuta"}>Terapeuta</option>
            <option value="Terapeuta Ocupacional" selected={@specialization_select == "Terapeuta Ocupacional"}>Terapeuta Ocupacional</option>
            <option value="Psicólogo" selected={@specialization_select == "Psicólogo"}>Psicólogo</option>
            <option value="Outro" selected={@specialization_select == "Outro"}>Outro</option>
          </select>
          <%= if @specialization_select == "Outro" do %>
            <input
              type="text"
              name="specialization_other"
              value={@specialization_other}
              maxlength="40"
              placeholder="Escreva a sua especialidade"
              class="border border-gray-300 rounded p-2 focus:border-gray-400 focus:ring-0"
            />
          <% end %>
          <button type="submit" class="rounded-lg bg-black hover:bg-blue-900 py-2 px-3 text-sm font-semibold leading-6 text-white active:text-white/80">
            Guardar Especialidade
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

    <%= if @confirm_delete_image do %>
      <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white p-6 rounded-lg shadow-lg w-full max-w-sm text-center">
          <h2 class="text-lg font-semibold mb-4">Tem a certeza?</h2>
          <p class="mb-6">Deseja mesmo apagar esta imagem de perfil?</p>
          <div class="flex justify-end space-x-4">
            <button
              phx-click="cancel_delete_image"
              class="px-4 py-2 bg-gray-300 rounded hover:bg-gray-400"
            >
              Cancelar
            </button>
            <button
              phx-click="delete_image"
              phx-value-image={@confirm_delete_image}
              class="px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700"
            >
              Apagar
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end

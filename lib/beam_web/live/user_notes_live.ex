defmodule BeamWeb.UserNotesLive do
  use BeamWeb, :live_view
  alias Beam.Accounts

  def mount(%{"patient_id" => patient_id}, _session, socket) do
    current_user = socket.assigns.current_user

    if current_user.type == "Terapeuta" do
      case Accounts.get_patient_with_user(patient_id) do
        nil ->
          {:ok, push_navigate(socket, to: "/dashboard")}

        patient ->
          therapist = Accounts.get_therapist_by_user_id(current_user.id)

          if therapist && therapist.therapist_id == patient.therapist_id do
            notes = Accounts.list_notes_for_patient(patient.patient_id)

            {:ok,
             assign(socket,
               patient: patient,
               therapist_id: therapist.therapist_id,
               notes: notes,
               new_note: ""
             )}
          else
            {:ok, push_navigate(socket, to: "/dashboard")}
          end
      end
    else
      {:ok, push_navigate(socket, to: "/dashboard")}
    end
  end

  def handle_event("update_note", %{"note" => note}, socket) do
    {:noreply, assign(socket, new_note: note)}
  end

  def handle_event("add_note", %{"note" => note}, socket) do
    attrs = %{
      description: note,
      therapist_id: socket.assigns.therapist_id,
      patient_id: socket.assigns.patient.patient_id
    }

    case Accounts.create_note(attrs) do
      {:ok, _note} ->
        updated_notes = Accounts.list_notes_for_patient(socket.assigns.patient.patient_id)

        {:noreply,
         assign(socket,
           notes: updated_notes,
           new_note: ""
         )}

      {:error, changeset} ->
        IO.inspect(changeset, label: "Erro ao criar nota")
        {:noreply, socket}
    end
  end

  def handle_event("delete_note", %{"note_id" => note_id}, socket) do
    IO.inspect(note_id, label: "ID da Nota a ser deletada")

    case Accounts.delete_note(note_id) do
      {:ok, _} ->
        updated_notes = Accounts.list_notes_for_patient(socket.assigns.patient.patient_id)

        {:noreply, assign(socket, notes: updated_notes)}

      {:error, _reason} ->
        IO.puts("Erro ao deletar nota.")
        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="flex p-6 space-x-6">
      <div class="flex flex-col">
        <h2 class="text-lg font-semibold">Nova Nota</h2>

        <form phx-submit="add_note" class="flex flex-col space-y-2">
          <textarea
            id="note-input"
            name="note"
            class="border border-gray-300 p-2 rounded w-64 h-32"
            phx-input="update_note"
            phx-debounce="300"
            value={@new_note}
          ></textarea>

          <button type="submit" class="bg-gray-900 text-white px-4 py-2 rounded w-full">
            Adicionar
          </button>
        </form>
      </div>

      <div class="flex flex-col flex-1">
        <h1 class="text-xl font-bold">{@patient.user.name}</h1>
        <div class="border border-gray-300 p-4 rounded w-full">
          <%= for note <- @notes do %>
            <div class="mb-4 border border-gray-200 p-2 rounded flex justify-between items-center">
              <div class="flex-1 pr-4">
                <p class="text-gray-600 text-sm">
                  {Calendar.strftime(note.inserted_at, "%d/%m/%Y")}
                </p>
                <p class="text-gray-900 break-words">{note.description}</p>
              </div>

              <button
                phx-click="delete_note"
                phx-value-note_id={note.id}
                onclick="return confirm('Tem certeza que deseja excluir esta nota?')"
                class="flex-shrink-0"
              >
                <img src="/images/trash.svg" alt="Deletar" class="w-5 h-5" />
              </button>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end

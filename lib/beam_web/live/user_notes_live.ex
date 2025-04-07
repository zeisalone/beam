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
               full_screen?: false,
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
    case Accounts.delete_note(note_id) do
      {:ok, _} ->
        updated_notes = Accounts.list_notes_for_patient(socket.assigns.patient.patient_id)
        {:noreply, assign(socket, notes: updated_notes)}

      {:error, _reason} ->
        IO.puts("Erro ao apagar nota.")
        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto mt-10 bg-white shadow-lg rounded-lg flex font-sans">
      <div class="w-1/3 p-8 border-r border-gray-200 bg-white max-h-[calc(100vh-250px)] overflow-y-auto">
        <h2 class="text-2xl font-bold mb-6 text-gray-900">Nova Nota</h2>
        <form phx-submit="add_note">
          <div class="mb-6">
            <textarea
              name="note"
              phx-input="update_note"
              phx-debounce="300"
              rows="8"
              class="w-full p-4 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent transition-all duration-200 resize-none text-sm"
              placeholder="Digite o conteúdo da sua nota"
              value={@new_note}
            ></textarea>
          </div>
          <button
            type="submit"
            class="w-full bg-purple-600 hover:bg-purple-700 text-white py-3 px-4 rounded-lg font-medium transition-colors duration-200 flex items-center justify-center"
          >
            Salvar Nota
          </button>
        </form>
      </div>

      <div class="w-2/3 p-8 bg-gray-50">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-gray-900">Notas de {@patient.user.name}</h2>
        </div>

        <div class="space-y-6 overflow-y-auto max-h-[calc(100vh-250px)]">
          <%= for note <- @notes do %>
            <div class="bg-white p-2 rounded-lg border border-gray-200 shadow-sm hover:shadow-md transition-shadow duration-200 group max-w-2xl mx-auto">
              <p class="text-gray-700 text-sm mb-4 leading-relaxed break-words whitespace-pre-line">
                {note.description}
              </p>
              <div class="flex justify-between items-center text-xs text-gray-500 pt-2">
                <span>Criado em: {Calendar.strftime(note.inserted_at, "%d/%m/%Y")}</span>
                <button
                  phx-click="delete_note"
                  phx-value-note_id={note.id}
                  onclick="return confirm('Tem certeza que deseja excluir esta nota?')"
                  class="text-gray-400 hover:text-red-500 transition duration-200 flex items-center space-x-1"
                >
                  <img src="/images/trash.svg" alt="Deletar" class="w-4 h-4" />
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end

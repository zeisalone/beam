defmodule BeamWeb.ExerciseConfig.ConfigEditLive do
  use BeamWeb, :live_view
  alias Beam.Exercices
  alias Beam.Exercices.ExerciseConfiguration
  alias Beam.Repo
  alias Beam.Accounts

  def mount(%{"task_id" => task_id}, _session, socket) do
    task = Exercices.get_task!(task_id)
    {:ok, module} = Beam.Exercices.configurable_module_for(task.name)

    default_data = module.default_config()
    spec = module.config_spec()

    therapist = Accounts.get_therapist_by_user_id(socket.assigns.current_user.id)
    therapist_id = therapist.therapist_id

    changeset =
      ExerciseConfiguration.changeset(%ExerciseConfiguration{}, %{
        name: "",
        data: default_data,
        public: false,
        task_id: task.id,
        therapist_id: therapist_id
      })

    {:ok,
     assign(socket,
       task: task,
       config_module: module,
       config_spec: spec,
       form: to_form(changeset),
       full_screen?: false,
       data: default_data,
       therapist_id: therapist_id
     )}
  end

  def handle_event("validate", %{"exercise_configuration" => params}, socket) do
    data = extract_data(params, socket.assigns.config_spec)

    changeset =
      %ExerciseConfiguration{}
      |> ExerciseConfiguration.changeset(%{
        name: params["name"] || "",
        data: data,
        public: Map.get(params, "public", false),
        task_id: socket.assigns.task.id,
        therapist_id: socket.assigns.therapist_id
      })
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset), data: data)}
  end

  def handle_event("save", %{"exercise_configuration" => params}, socket) do
    data = extract_data(params, socket.assigns.config_spec)

    attrs = %{
      name: params["name"] || "",
      data: data,
      public: Map.get(params, "public", false),
      task_id: socket.assigns.task.id,
      therapist_id: socket.assigns.therapist_id
    }

    case Repo.insert(ExerciseConfiguration.changeset(%ExerciseConfiguration{}, attrs)) do
      {:ok, _config} ->
        {:noreply,
         socket
         |> put_flash(:info, "Configuração guardada com sucesso")
         |> push_navigate(to: ~p"/tasks")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset), data: data)}
    end
  end

  defp extract_data(params, spec) do
    Enum.reduce(spec, %{}, fn {key, type, _opts}, acc ->
      raw = Map.get(params, Atom.to_string(key))

      value =
        case type do
          :integer -> parse_int(raw)
          :float -> parse_float(raw)
          :string -> raw
          :select -> raw
        end

      Map.put(acc, key, value)
    end)
  end

  defp parse_int(nil), do: nil
  defp parse_int(val), do: String.to_integer(val)

  defp parse_float(nil), do: nil
  defp parse_float(val), do: String.to_float(val)

  def render(assigns) do
    ~H"""
    <div class="p-10">
      <.header>
        Editar tarefa: <%= @task.name %>
      </.header>

      <%= if Phoenix.Flash.get(@flash, :info) do %>
        <div class="mb-4 p-2 bg-green-100 border border-green-300 text-green-800 rounded">
          <%= Phoenix.Flash.get(@flash, :info) %>
        </div>
      <% end %>

      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} label="Nome da Configuração" />

        <%= for {key, type, opts} <- @config_spec do %>
          <%= if opts[:options] do %>
           <.input
              type="select"
              field={@form[String.to_atom(to_string(key))]}
              name={"exercise_configuration[#{key}]"}
              options={Enum.map(opts[:options], &{&1, &1})}
              value={@data[key]}
              label={opts[:label] || humanize(key)}
            />
          <% else %>
            <.input
              type={input_type(type)}
              field={@form[String.to_atom(to_string(key))]}
              name={"exercise_configuration[#{key}]"}
              value={@data[key]}
              label={opts[:label] || humanize(key)}
              step={type == :float && "any"}
            />
          <% end %>
        <% end %>

        <.input type="checkbox" field={@form[:public]} label="Edição usável por outros terapeutas?" />

        <:actions>
          <.button type="submit">Guardar Configuração</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  defp input_type(:integer), do: "number"
  defp input_type(:float), do: "number"
  defp input_type(:string), do: "text"
  defp input_type(:select), do: "select"

  defp humanize(atom) do
    atom |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
  end
end

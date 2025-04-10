defmodule BeamWeb.TaskController do
  use BeamWeb, :controller

  alias Beam.Exercices
  alias Beam.Exercices.Task

  @tag_colors %{
    "Memória de Trabalho" => "bg-purple-100 text-purple-700 hover:bg-purple-200",
    "Atenção Sustentada" => "bg-blue-100 text-blue-700 hover:bg-blue-200",
    "Velocidade de Reação" => "bg-yellow-100 text-yellow-700 hover:bg-yellow-200",
    "Atenção Visual" => "bg-green-100 text-green-700 hover:bg-green-200",
    "Atenção Focada" => "bg-pink-100 text-pink-700 hover:bg-pink-200",
    "Manipulação Cognitiva" => "bg-indigo-100 text-indigo-700 hover:bg-indigo-200",
    "Atenção Seletiva" => "bg-lime-100 text-lime-700 hover:bg-lime-200",
    "Inibição de Resposta" => "bg-red-100 text-red-700 hover:bg-red-200",
    "Flexibilidade Cognitiva" => "bg-orange-100 text-orange-700 hover:bg-orange-200"
  }

  def index(conn, _params) do
    current_user = conn.assigns.current_user
    tasks = Exercices.list_tasks()

    unseen_tasks =
      if current_user.type == "Paciente" do
        Exercices.list_unseen_recommendations(current_user.id)
      else
        []
      end

    render(conn, :index,
      tasks: tasks,
      unseen_tasks: unseen_tasks,
      tag_colors: @tag_colors
    )
  end

  def new(conn, _params) do
    changeset = Exercices.change_task(%Task{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"task" => task_params}) do
    case Exercices.create_task(task_params) do
      {:ok, task} ->
        conn
        |> put_flash(:info, "Task created successfully.")
        |> redirect(to: ~p"/tasks/#{task}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    redirect(conn, to: "/tasks/#{id}")
  end

  def edit(conn, %{"id" => id}) do
    task = Exercices.get_task!(id)
    changeset = Exercices.change_task(task)
    render(conn, :edit, task: task, changeset: changeset)
  end

  def update(conn, %{"id" => id, "task" => task_params}) do
    task = Exercices.get_task!(id)

    case Exercices.update_task(task, task_params) do
      {:ok, task} ->
        conn
        |> put_flash(:info, "Task updated successfully.")
        |> redirect(to: ~p"/tasks/#{task}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, task: task, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    task = Exercices.get_task!(id)
    {:ok, _task} = Exercices.delete_task(task)

    conn
    |> put_flash(:info, "Task deleted successfully.")
    |> redirect(to: ~p"/tasks")
  end
end

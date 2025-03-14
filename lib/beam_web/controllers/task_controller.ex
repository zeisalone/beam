defmodule BeamWeb.TaskController do
  use BeamWeb, :controller

  alias Beam.Exercices
  alias Beam.Exercices.Task

  def index(conn, _params) do
    current_user = conn.assigns.current_user
    tasks = Exercices.list_tasks()

    unseen_tasks =
      if current_user.type == "Paciente" do
        Exercices.list_unseen_recommendations(current_user.id)
      else
        []
      end

    render(conn, :index, tasks: tasks, unseen_tasks: unseen_tasks)
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

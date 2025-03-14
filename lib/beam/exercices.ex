defmodule Beam.Exercices do
  @moduledoc """
  The Exercices context.
  """

  import Ecto.Query, warn: false
  alias Beam.Repo
  alias Beam.Exercices.{Recommendation, Task, Result, Test, Training}

  def list_tasks do
    Repo.all(Task)
  end

  def get_task!(id), do: Repo.get!(Task, id)
  def get_task_by_name(name), do: Repo.get_by(Task, name: name)

  @spec create_task() :: any()
  def create_task(attrs \\ %{}) do
    %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()
  end

  def update_task(%Task{} = task, attrs) do
    task
    |> Task.changeset(attrs)
    |> Repo.update()
  end

  def delete_task(%Task{} = task) do
    Repo.delete(task)
  end

  def change_task(%Task{} = task, attrs \\ %{}) do
    Task.changeset(task, attrs)
  end

  alias Beam.Exercices.Result

  def list_results do
    Repo.all(Result)
  end

  def get_result!(id), do: Repo.get!(Result, id)

  def create_result(attrs \\ %{}) do
    %Result{}
    |> Result.changeset(attrs)
    |> Repo.insert()
  end

  def update_result(%Result{} = result, attrs) do
    result
    |> Result.changeset(attrs)
    |> Repo.update()
  end

  def delete_result(%Result{} = result) do
    Repo.delete(result)
  end

  def change_result(%Result{} = result, attrs \\ %{}) do
    Result.changeset(result, attrs)
  end

  def list_task_results(task_id) do
    results = Repo.all(from r in Result, where: r.task_id == ^task_id)

    Enum.map(results, fn result ->
      type =
        case Repo.get_by(Test, result_id: result.id) do
          %Test{} ->
            "Teste"

          nil ->
            case Repo.get_by(Training, result_id: result.id) do
              %Training{difficulty: difficulty} -> "Treino (#{difficulty})"
              nil -> "Desconhecido"
            end
        end

      Map.put(result, :result_type, type)
    end)
  end

  def get_task_by_type(type) do
    Repo.get_by(Task, type: type)
  end

  def list_results_by_user(user_id) do
    results = Repo.all(from r in Result, where: r.user_id == ^user_id)

    Enum.map(results, fn result ->
      type =
        case Repo.get_by(Test, result_id: result.id) do
          %Test{} ->
            "Teste"

          nil ->
            case Repo.get_by(Training, result_id: result.id) do
              %Training{difficulty: difficulty} -> "Treino (#{difficulty})"
              nil -> "Desconhecido"
            end
        end

      Map.put(result, :result_type, type)
    end)
  end

  def list_results_by_patient(patient_id) do
    case Beam.Repo.get(Beam.Accounts.Patient, patient_id) do
      nil ->
        []

      patient ->
        Beam.Repo.all(from r in Beam.Exercices.Result, where: r.user_id == ^patient.user_id)
    end
  end

  def get_task_name(task_id) do
    case Beam.Repo.get(Beam.Exercices.Task, task_id) do
      nil -> "Desconhecido"
      task -> task.name
    end
  end

  def list_results_by_user_and_task(user_id, task_id) do
    results =
      Repo.all(from r in Result, where: r.user_id == ^user_id and r.task_id == ^task_id)

    Enum.map(results, fn result ->
      type =
        case Repo.get_by(Test, result_id: result.id) do
          %Test{} ->
            "Teste"

          nil ->
            case Repo.get_by(Training, result_id: result.id) do
              %Training{difficulty: difficulty} -> "Treino (#{difficulty})"
              nil -> "Desconhecido"
            end
        end

      Map.put(result, :result_type, type)
    end)
  end

  def recommend_task(%{task_id: task_id, patient_id: patient_id, therapist_id: therapist_id}) do
    recommendation =
      %Recommendation{}
      |> Recommendation.changeset(%{
        task_id: task_id,
        patient_id: patient_id,
        therapist_id: therapist_id
      })
      |> Repo.insert()

    recommendation
  end

  def list_unseen_recommendations(user_id) do
    case Repo.get_by(Beam.Accounts.Patient, user_id: user_id) do
      nil ->
        []

      patient ->
        unseen =
          Repo.all(
            from r in Recommendation,
              where: r.patient_id == ^patient.patient_id and r.seen == false,
              select: r.task_id
          )

        unseen
    end
  end

  def mark_recommendation_as_seen(task_id, user_id) do
    case Repo.get_by(Beam.Accounts.Patient, user_id: user_id) do
      nil ->
        0

      patient ->
        {count, _} =
          from(r in Recommendation,
            where:
              r.task_id == ^task_id and r.patient_id == ^patient.patient_id and r.seen == false,
            update: [set: [seen: true]]
          )
          |> Repo.update_all([])

        count
    end
  end

  def get_latest_attempt(user_id, task_id) do
    case Repo.one(
           from t in Test,
             where: t.user_id == ^user_id and t.task_id == ^task_id,
             order_by: [desc: t.attempt_number],
             select: t.attempt_number,
             limit: 1
         ) do
      nil -> 0
      attempt_number -> attempt_number
    end
  end

  def save_test_attempt(user_id, task_id, result_id) do
    latest_attempt = get_latest_attempt(user_id, task_id)

    %Test{}
    |> Test.changeset(%{
      user_id: user_id,
      task_id: task_id,
      result_id: result_id,
      attempt_number: latest_attempt + 1
    })
    |> Repo.insert()
  end

  def get_latest_training_attempt(user_id, task_id) do
    case Repo.one(
           from t in Training,
             where: t.user_id == ^user_id and t.task_id == ^task_id,
             order_by: [desc: t.attempt_number],
             select: t.attempt_number,
             limit: 1
         ) do
      nil -> 0
      attempt_number -> attempt_number
    end
  end

  def save_training_attempt(user_id, task_id, result_id, difficulty) do
    latest_attempt = get_latest_training_attempt(user_id, task_id)

    %Training{}
    |> Training.changeset(%{
      user_id: user_id,
      task_id: task_id,
      result_id: result_id,
      attempt_number: latest_attempt + 1,
      difficulty: difficulty
    })
    |> Repo.insert()
  end
end

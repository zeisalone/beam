defmodule Beam.Exercices do
  @moduledoc """
  The Exercices context.
  """

  import Ecto.Query, warn: false
  alias Beam.Repo
  alias Beam.Exercices.{Recommendation, Task, Result, Test, Training, ExerciseConfiguration}

  def list_tasks do
    from(t in Task, order_by: t.id)
    |> Repo.all()
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

    results
    |> Enum.filter(fn result ->
      case Beam.Repo.get(Beam.Accounts.User, result.user_id) do
        %{type: "Paciente"} -> true
        _ -> false
      end
    end)
    |> Enum.map(fn result ->
      type =
        case Repo.get_by(Test, result_id: result.id) do
          %Test{} -> "Teste"
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

  def recommend_task(%{
    task_id: task_id,
    patient_id: patient_id,
    therapist_id: therapist_id,
    type: type,
    difficulty: difficulty
  }) do
  ecto_type = case type do
    "training" -> :treino
    "test" -> :teste
  end

  ecto_difficulty =
    if ecto_type == :treino do
      difficulty && String.to_existing_atom(difficulty)
    else
      nil
    end

  %Recommendation{}
  |> Recommendation.changeset(%{
    task_id: task_id,
    patient_id: patient_id,
    therapist_id: therapist_id,
    type: ecto_type,
    difficulty: ecto_difficulty
  })
  |> Repo.insert()
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

  def list_unseen_recommendations_with_info(user_id) do
    case Repo.get_by(Beam.Accounts.Patient, user_id: user_id) do
      nil -> []
      patient ->
        Repo.all(
          from r in Beam.Exercices.Recommendation,
            where: r.patient_id == ^patient.patient_id and r.seen == false,
            join: t in Beam.Exercices.Task, on: r.task_id == t.id,
            select: %{
              task_id: t.id,
              task_name: t.name,
              type: r.type,
              difficulty: r.difficulty
            }
        )
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

  def count_exercises_this_week do
    start_of_week =
      Date.beginning_of_week(Date.utc_today())
      |> DateTime.new!(~T[00:00:00], "Etc/UTC")

    query =
      from r in Beam.Exercices.Result,
        join: u in Beam.Accounts.User,
        on: r.user_id == u.id,
        where: r.inserted_at >= ^start_of_week and u.type == "Paciente"

    Repo.aggregate(query, :count)
  end

  def count_active_patients_this_week(therapist_user_id) do
    start_of_week =
      Date.beginning_of_week(Date.utc_today())
      |> DateTime.new!(~T[00:00:00], "Etc/UTC")

    query =
      from r in Beam.Exercices.Result,
        join: p in Beam.Accounts.Patient,
        on: r.user_id == p.user_id,
        where: r.inserted_at >= ^start_of_week,
        join: t in Beam.Accounts.Therapist,
        on: p.therapist_id == t.therapist_id,
        where: t.user_id == ^therapist_user_id,
        select: p.patient_id,
        distinct: true

    Repo.aggregate(query, :count)
  end

  def task_has_full_sequence?(task_id) do
    task = get_task!(task_id)
    task.name in ["Sequência Inversa", "Ordenar os Animais"]
  end

  def get_oldest_unseen_recommendation(task_id, user_id) do
    case Repo.get_by(Beam.Accounts.Patient, user_id: user_id) do
      nil -> nil
      patient ->
        Repo.one(
          from r in Beam.Exercices.Recommendation,
            where: r.patient_id == ^patient.patient_id and r.task_id == ^task_id and r.seen == false,
            order_by: [asc: r.inserted_at],
            preload: [therapist: [:user], configuration: []],
            limit: 1
        )
    end
  end

  def list_categories do
    Task
    |> Repo.all()
    |> Enum.flat_map(& &1.tags)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def list_results_by_category(category) do
    query =
      from r in Result,
        join: t in Task, on: r.task_id == t.id,
        where: ^category in t.tags,
        preload: [:task, :user]

    Repo.all(query)
    |> Enum.map(fn result ->
      result_type =
        case Repo.get_by(Test, result_id: result.id) do
          %Test{} -> "Teste"
          nil ->
            case Repo.get_by(Training, result_id: result.id) do
              %Training{difficulty: difficulty} -> "Treino (#{difficulty})"
              nil -> "Desconhecido"
            end
        end

        Map.merge(result, %{result_type: result_type})
    end)
  end

  @spec configurable_module_for(String.t()) :: {:ok, module()} | {:error, :not_configurable}
  def configurable_module_for(task_name) do
    case task_name do
      "Sequência Inversa" -> {:ok, Beam.Exercices.Tasks.ReverseSequence}
      "Ordenar os Animais" -> {:ok, Beam.Exercices.Tasks.OrderAnimals}
      "Simon" -> {:ok, Beam.Exercices.Tasks.Simon}
      "Procurar a Vogal" -> {:ok, Beam.Exercices.Tasks.SearchingForAVowel}
      "Procurar uma resposta" -> {:ok, Beam.Exercices.Tasks.SearchingForAnAnswer}
      "Segue a Figura" -> {:ok, Beam.Exercices.Tasks.FollowTheFigure}
      "Menor que 5" -> {:ok, Beam.Exercices.Tasks.LessThanFive}
      "Matemática" -> {:ok, Beam.Exercices.Tasks.MathOperation}
      "Código de Símbolos" -> {:ok, Beam.Exercices.Tasks.CodeOfSymbols}
      "Stroop" -> {:ok, Beam.Exercices.Tasks.NameAndColor}
      "O diferente" -> {:ok, Beam.Exercices.Tasks.OddOneOut}
      _ -> {:error, :not_configurable}
    end
  end

  def list_exercise_configurations_with_task do
    Repo.all(
      from c in ExerciseConfiguration,
        join: t in assoc(c, :task),
        preload: [task: t],
        order_by: [desc: c.inserted_at]
    )
  end

  def list_visible_exercise_configurations_with_task do
    Repo.all(
      from c in ExerciseConfiguration,
        where: not coalesce(c.hide, false),
        join: t in assoc(c, :task),
        preload: [task: t],
        order_by: [desc: c.inserted_at]
    )
  end

  def hide_exercise_configuration(config_id) do
    case Repo.get(ExerciseConfiguration, config_id) do
      nil -> {:error, :not_found}
      config ->
        config
        |> Ecto.Changeset.change(%{hide: true})
        |> Repo.update()
    end
  end

  def recommend_custom_configuration(%{
        config_id: config_id,
        patient_id: patient_id,
        therapist_id: therapist_id
      }) do
    config = Repo.get!(ExerciseConfiguration, config_id)

    %Recommendation{}
    |> Recommendation.changeset(%{
      task_id: config.task_id,
      configuration_id: config.id,
      patient_id: patient_id,
      therapist_id: therapist_id,
      type: :treino,
      difficulty: :criado
    })
    |> Repo.insert()
  end

  def average_accuracy_per_task(opts \\ %{}) do
    age_range = Map.get(opts, :age_range)
    gender = Map.get(opts, :gender)
    education = Map.get(opts, :education)
    therapist_user_id = Map.get(opts, :therapist_user_id)

    base_query =
      from r in Beam.Exercices.Result,
        join: u in Beam.Accounts.User, on: r.user_id == u.id,
        join: p in Beam.Accounts.Patient, on: u.id == p.user_id,
        join: t in Beam.Exercices.Task, on: r.task_id == t.id,
        where: u.type == "Paciente"

    base_query =
      if therapist_user_id do
        from [r, u, p, t] in base_query,
          join: th in Beam.Accounts.Therapist, on: p.therapist_id == th.therapist_id,
          where: th.user_id == ^therapist_user_id
      else
        base_query
      end

    base_query =
      if age_range do
        {min_age, max_age} = age_range

        from [r, u, p, t] in base_query,
          where:
            fragment(
              "FLOOR(DATE_PART('year', AGE(current_date, ?)))",
              p.birth_date
            ) >= ^min_age and
            fragment(
              "FLOOR(DATE_PART('year', AGE(current_date, ?)))",
              p.birth_date
            ) <= ^max_age
      else
        base_query
      end

    base_query =
      if is_binary(gender) and gender not in ["", "Todos os géneros"] do
        from [r, u, p, t] in base_query,
          where: p.gender == ^gender
      else
        base_query
      end

    base_query =
      if is_binary(education) and education not in ["", "Todos os níveis"] do
        from [r, u, p, t] in base_query,
          where: p.education_level == ^education
      else
        base_query
      end

    final_query =
      from [r, _u, _p, t] in base_query,
        group_by: [r.task_id, t.id, t.name],
        select: %{
          task_id: t.id,
          task_name: t.name,
          avg_accuracy: avg(r.accuracy)
        }

    Repo.all(final_query)
  end

  def average_reaction_time_per_task(opts \\ %{}) do
    age_range = Map.get(opts, :age_range)
    gender = Map.get(opts, :gender)
    education = Map.get(opts, :education)
    therapist_user_id = Map.get(opts, :therapist_user_id)

    base_query =
      from r in Beam.Exercices.Result,
        join: u in Beam.Accounts.User, on: r.user_id == u.id,
        join: p in Beam.Accounts.Patient, on: u.id == p.user_id,
        join: t in Beam.Exercices.Task, on: r.task_id == t.id,
        where: u.type == "Paciente"

    base_query =
      if therapist_user_id do
        from [r, u, p, t] in base_query,
          join: th in Beam.Accounts.Therapist, on: p.therapist_id == th.therapist_id,
          where: th.user_id == ^therapist_user_id
      else
        base_query
      end

    base_query =
      if age_range do
        {min_age, max_age} = age_range

        from [r, u, p, t] in base_query,
          where:
            fragment("FLOOR(DATE_PART('year', AGE(current_date, ?)))", p.birth_date) >= ^min_age and
            fragment("FLOOR(DATE_PART('year', AGE(current_date, ?)))", p.birth_date) <= ^max_age
      else
        base_query
      end

    base_query =
      if is_binary(gender) and gender not in ["", "Todos os géneros"] do
        from [r, u, p, t] in base_query,
          where: p.gender == ^gender
      else
        base_query
      end

    base_query =
      if is_binary(education) and education not in ["", "Todos os níveis"] do
        from [r, u, p, t] in base_query,
          where: p.education_level == ^education
      else
        base_query
      end

    final_query =
      from [r, _u, _p, t] in base_query,
        group_by: [r.task_id, t.id, t.name],
        select: %{
          task_id: t.id,
          task_name: t.name,
          avg_reaction_time: avg(r.reaction_time)
        }

    Repo.all(final_query)
  end

  def average_accuracy_per_task_for_user(user_id) do
    from(r in Beam.Exercices.Result,
      join: t in Beam.Exercices.Task, on: r.task_id == t.id,
      where: r.user_id == ^user_id,
      group_by: [r.task_id, t.name],
      select: %{
        task_id: r.task_id,
        task_name: t.name,
        avg_accuracy: avg(r.accuracy)
      }
    )
    |> Repo.all()
  end

  def average_reaction_time_per_task_for_user(user_id) do
    from(r in Beam.Exercices.Result,
      join: t in Beam.Exercices.Task, on: r.task_id == t.id,
      where: r.user_id == ^user_id,
      group_by: [r.task_id, t.name],
      select: %{
        task_id: r.task_id,
        task_name: t.name,
        avg_reaction_time: avg(r.reaction_time)
      }
    )
    |> Repo.all()
  end

  def list_configuration_accesses_for_config(config_id) do
    from(a in Beam.Exercices.ExerciseConfigurationAccess,
      where: a.configuration_id == ^config_id,
      join: p in Beam.Accounts.Patient,
      on: a.patient_id == p.patient_id,
      preload: [configuration: :task, patient: p]
    )
    |> Beam.Repo.all()
  end

  def add_exercise_configuration_access(attrs) do
    %Beam.Exercices.ExerciseConfigurationAccess{}
    |> Beam.Exercices.ExerciseConfigurationAccess.changeset(attrs)
    |> Beam.Repo.insert()
  end

  def remove_exercise_configuration_access(config_id, patient_id) do
    from(a in Beam.Exercices.ExerciseConfigurationAccess,
      where: a.configuration_id == ^config_id and a.patient_id == ^patient_id
    )
    |> Beam.Repo.one()
    |> case do
      nil -> {:error, :not_found}
      access -> Beam.Repo.delete(access)
    end
  end

  def has_taken_diagnostic_test?(user_id, task_id) do
    Repo.exists?(
      from t in Test,
        where: t.user_id == ^user_id and t.task_id == ^task_id and t.attempt_number == 1
    )
  end

  def get_diagnostic_test(user_id, task_id) do
    Repo.one(
      from t in Test,
        where: t.user_id == ^user_id and t.task_id == ^task_id and t.attempt_number == 1,
        join: r in Result, on: r.id == t.result_id,
        preload: [result: r],
        select: r
    )
  end

  def average_test_accuracy_per_task_for_user(user_id) do
    from(test in Beam.Exercices.Test,
      join: result in Beam.Exercices.Result, on: test.result_id == result.id,
      join: task in Beam.Exercices.Task, on: test.task_id == task.id,
      where: test.user_id == ^user_id,
      group_by: [task.id, task.name],
      select: %{
        task_id: task.id,
        task_name: task.name,
        avg_accuracy: avg(result.accuracy)
      }
    )
    |> Repo.all()
  end

  def average_test_accuracy_per_task do
    from(test in Beam.Exercices.Test,
      join: result in Beam.Exercices.Result, on: test.result_id == result.id,
      join: task in Beam.Exercices.Task, on: test.task_id == task.id,
      group_by: [task.id, task.name],
      select: %{
        task_id: task.id,
        task_name: task.name,
        avg_accuracy: avg(result.accuracy)
      }
    )
    |> Repo.all()
  end

  def aggregate_user_stats_over_time(user_id, metric \\ :accuracy, period \\ :day, limit \\ 30, task_id \\ nil) do
    date_trunc =
      case period do
        :day -> "day"
        :week -> "week"
        :month -> "month"
        _ -> "day"
      end

    metric_field =
      case metric do
        :reaction_time -> :reaction_time
        _ -> :accuracy
      end

    q =
      from r in Beam.Exercices.Result,
        where: r.user_id == ^user_id,
        select: %{
          period: fragment("DATE_TRUNC(?, ?)", ^date_trunc, r.inserted_at),
          metric: field(r, ^metric_field),
          task_id: r.task_id
        }

    q =
      if task_id do
        from r in q, where: r.task_id == ^task_id
      else
        q
      end

    from(
      s in subquery(q),
      group_by: s.period,
      select: %{
        date: s.period,
        value: avg(s.metric)
      },
      order_by: [desc: s.period],
      limit: ^limit
    )
    |> Repo.all()
    |> Enum.reverse()
  end

  def diagnostic_test_results_per_task_for_user(user_id) do
    from(t in Beam.Exercices.Task)
    |> Repo.all()
    |> Enum.map(fn task ->
      case Repo.one(
            from test in Beam.Exercices.Test,
              where: test.user_id == ^user_id and test.task_id == ^task.id and test.attempt_number == 1,
              join: result in Beam.Exercices.Result, on: result.id == test.result_id,
              select: result
          ) do
        nil -> nil
        result ->
          %{
            task_id: task.id,
            task_name: task.name,
            diagnostic_accuracy: result.accuracy,
            diagnostic_reaction_time: result.reaction_time
          }
      end
    end)
    |> Enum.filter(& &1)
  end
end

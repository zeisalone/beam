defmodule BeamWeb.Tasks.NameAndColorLive do
  use BeamWeb, :live_view
  alias Beam.Exercices.Tasks.NameAndColor
  alias Beam.Repo
  alias Beam.Exercices.Result

  @default_total_trials 20
  @default_display_times %{facil: 3000, medio: 2000, dificil: 1500, default: 2000}
  @default_question_times %{facil: 5500, medio: 5000, dificil: 5000, default: 5000}

  @impl true
  def mount(_params, session, socket) do
    current_user = Map.get(session, "current_user")
    task_id = Map.get(session, "task_id")
    live_action = Map.get(session, "live_action", "training") |> String.to_existing_atom()
    full_screen = Map.get(session, "full_screen?", true)

    difficulty =
      case live_action do
        :training -> Map.get(session, "difficulty", "medio") |> String.to_existing_atom()
        _ -> :criado
      end

    raw_config = Map.get(session, "config", %{})

    config =
      Map.merge(NameAndColor.default_config(),
        if(is_map(raw_config), do: atomize_keys(raw_config), else: %{})
      )

    total_trials = Map.get(config, :total_trials, @default_total_trials)

    display_time =
      case Map.get(config, :display_time) do
        val when is_binary(val) -> String.to_integer(val)
        val when is_integer(val) -> val
        _ -> Map.get(@default_display_times, difficulty, @default_display_times.default)
      end

    question_time =
      case Map.get(config, :question_time) do
        val when is_binary(val) -> String.to_integer(val)
        val when is_integer(val) -> val
        _ -> Map.get(@default_question_times, difficulty, @default_question_times.default)
      end

    question_type = Map.get(config, :question_type, "Ambas")

    if connected?(socket), do: Process.send_after(self(), :start_intro, 500)

    trials = NameAndColor.generate_trials(total_trials)

    {:ok,
     assign(socket,
       current_user: current_user,
       user_id: current_user.id,
       task_id: task_id,
       live_action: live_action,
       difficulty: difficulty,
       trials: trials,
       current_index: 0,
       current_trial: nil,
       show_question: false,
       display_text: nil,
       display_color: nil,
       question: nil,
       options: [],
       start_time: nil,
       correct: 0,
       wrong: 0,
       omitted: 0,
       total_reaction_time: 0,
       awaiting_response: false,
       results: [],
       full_screen?: full_screen,
       show_intro: true,
       finished: false,
       total_trials: total_trials,
       display_time: display_time,
       question_time: question_time,
       question_type: question_type,
       config: config
     )}
  end

  @impl true
  def handle_info(:start_intro, socket) do
    Process.send_after(self(), :start_trial, 2000)
    {:noreply, assign(socket, show_intro: true)}
  end

  def handle_info(:start_trial, socket) do
    index = socket.assigns.current_index

    if index < socket.assigns.total_trials do
      trial = Enum.at(socket.assigns.trials, index)
      Process.send_after(self(), :show_question, socket.assigns.display_time)

      {:noreply,
       assign(socket,
         current_trial: trial,
         display_text: trial.word,
         display_color: trial.color,
         question: nil,
         options: [],
         show_question: false,
         awaiting_response: false,
         show_intro: false
       )}
    else
      Process.send_after(self(), :save_results, 0)
      {:noreply, assign(socket, finished: true)}
    end
  end

  def handle_info(:show_question, socket) do
    trial = socket.assigns.current_trial

    question =
      case socket.assigns.difficulty do
        :criado ->
          case socket.assigns.question_type do
            "Pela Palavra" -> :word
            "Pela Cor" -> :color
            "Ambas" -> Enum.random([:word, :color])
            _ -> :word
          end

        :facil -> :color
        :medio -> :word
        :dificil -> Enum.random([:word, :color])
        _ -> :word
      end

    options = NameAndColor.generate_options(trial, question)
    timeout = socket.assigns.question_time
    omission_ref = Process.send_after(self(), :handle_omission, timeout)

    {:noreply,
     assign(socket,
       show_question: true,
       question: question,
       options: options,
       start_time: System.monotonic_time(),
       awaiting_response: true,
       omission_timer_ref: omission_ref
     )}
  end

  def handle_info(:handle_omission, socket) do
    if socket.assigns.awaiting_response do
      update_result(:omitted, socket, 0)
    else
      {:noreply, socket}
    end
  end

  def handle_info(:save_results, socket) do
    result = %{
      user_id: socket.assigns.user_id,
      task_id: socket.assigns.task_id,
      correct: socket.assigns.correct,
      wrong: socket.assigns.wrong,
      omitted: socket.assigns.omitted,
      accuracy: if(socket.assigns.total_trials > 0, do: socket.assigns.correct / socket.assigns.total_trials, else: 0.0),
      reaction_time: if(socket.assigns.total_trials > 0, do: socket.assigns.total_reaction_time / socket.assigns.total_trials, else: 0.0)
    }

    case Repo.insert(Result.changeset(%Result{}, result)) do
      {:ok, result} ->
        case socket.assigns.live_action do
          :test -> Beam.Exercices.save_test_attempt(socket.assigns.user_id, socket.assigns.task_id, result.id)
          :training -> Beam.Exercices.save_training_attempt(socket.assigns.user_id, socket.assigns.task_id, result.id, socket.assigns.difficulty)
        end

        {:noreply, push_navigate(socket, to: "/results/aftertask?task_id=#{socket.assigns.task_id}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao guardar resultados.")}
    end
  end

  @impl true
  def handle_event("submit_answer", %{"answer" => answer}, socket) do
    if socket.assigns.awaiting_response do
      Process.cancel_timer(socket.assigns.omission_timer_ref)

      reaction_time =
        System.monotonic_time() - socket.assigns.start_time
        |> System.convert_time_unit(:native, :millisecond)

      correct_answer = NameAndColor.correct_answer(socket.assigns.current_trial, socket.assigns.question)
      result = if answer == correct_answer, do: :correct, else: :wrong

      update_result(result, assign(socket, omission_timer_ref: nil), reaction_time)
    else
      {:noreply, socket}
    end
  end

  defp update_result(result, socket, reaction_time) do
    index = socket.assigns.current_index + 1

    updates =
      case result do
        :correct -> %{correct: socket.assigns.correct + 1}
        :wrong -> %{wrong: socket.assigns.wrong + 1}
        :omitted -> %{omitted: socket.assigns.omitted + 1}
      end

    new_results = [%{result: result, time: reaction_time} | socket.assigns.results]

    Process.send_after(self(), :start_trial, 200)

    {:noreply,
     assign(socket,
       current_index: index,
       awaiting_response: false,
       total_reaction_time: socket.assigns.total_reaction_time + reaction_time,
       results: new_results
     )
     |> assign(updates)}
  end

  defp atomize_keys(map) do
    for {k, v} <- map, into: %{} do
      key = if is_binary(k), do: String.to_existing_atom(k), else: k
      {key, v}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 w-screen h-screen flex items-center justify-center bg-white">
      <div class="w-full max-w-2xl text-center px-4">
        <%= if @show_intro do %>
          <p class="text-2xl font-bold text-gray-700 animate-pulse">A preparar exercício...</p>
        <% else %>
          <%= if @finished do %>
            <p class="text-xl font-semibold text-gray-700">A calcular resultados...</p>
          <% else %>
            <%= if not @show_question do %>
              <p class="text-5xl font-bold mb-8" style={"color: #{@display_color}"}><%= @display_text %></p>
            <% else %>
              <p class="text-xl mb-4">
                Qual era a <strong><%= if @question == :word, do: "PALAVRA", else: "COR" %></strong>?
              </p>
              <div class="flex flex-wrap justify-center gap-4">
                <%= for option <- @options do %>
                  <button
                    phx-click="submit_answer"
                    phx-value-answer={option}
                    class="px-6 py-3 bg-blue-500 text-white rounded shadow hover:bg-blue-600 text-xl"
                  >
                    <%= option %>
                  </button>
                <% end %>
              </div>
            <% end %>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end
end

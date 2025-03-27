defmodule BeamWeb.DynamicTaskLive do
  use BeamWeb, :live_view
  alias Beam.Repo
  alias Beam.Exercices.Task

  @impl true
  def mount(%{"task_id" => task_id} = params, _session, socket) do
    current_user = Map.get(socket.assigns, :current_user, nil)
    live_action = params["live_action"] |> maybe_to_atom()
    difficulty = params["difficulty"] |> maybe_to_atom()

    case Repo.get(Task, task_id) do
      nil ->
        {:ok, push_navigate(socket, to: "/tasks")}

      %Task{type: "math_operation"} ->
        {:ok, assign_task(socket, BeamWeb.MathOperationLive, params, current_user, live_action, difficulty)}

      %Task{type: "searching_for_an_answer"} ->
        {:ok, assign_task(socket, BeamWeb.SearchingForAnAnswerLive, params, current_user, live_action, difficulty)}

      %Task{type: "greater_than_five"} ->
        {:ok, assign_task(socket, BeamWeb.GreaterThanFiveLive, params, current_user, live_action, difficulty)}

      %Task{type: "reverse_sequence"} ->
        {:ok, assign_task(socket, BeamWeb.ReverseSequenceLive, params, current_user, live_action, difficulty)}

      %Task{type: "code_of_symbols"} ->
        {:ok, assign_task(socket, BeamWeb.CodeOfSymbolsLive, params, current_user, live_action, difficulty)}

      _ ->
        {:ok, push_navigate(socket, to: "/tasks")}
    end
  end

  defp assign_task(socket, live_view, params, current_user, live_action, difficulty) do
    assign(socket,
      live_view: live_view,
      params: params,
      current_user: current_user,
      live_action: live_action,
      difficulty: difficulty
    )
  end

  defp maybe_to_atom(nil), do: nil
  defp maybe_to_atom(value) when is_binary(value), do: String.to_existing_atom(value)
  defp maybe_to_atom(_), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    {live_render(@socket, @live_view,
      id: "task_#{@params["task_id"]}",
      session: %{
        "task_id" => @params["task_id"],
        "live_action" => Atom.to_string(@live_action),
        "difficulty" => Atom.to_string(@difficulty),
        "current_user" => @current_user
      }
    )}
    """
  end
end

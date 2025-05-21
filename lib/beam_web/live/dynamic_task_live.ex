defmodule BeamWeb.DynamicTaskLive do
  use BeamWeb, :live_view
  alias Beam.Repo
  alias Beam.Exercices.Task

  @impl true
  def mount(%{"task_id" => task_id} = params, _session, socket) do
    current_user = socket.assigns[:current_user] || raise "Current user not found"
    live_action = maybe_to_atom(params["live_action"])
    difficulty = maybe_to_atom(params["difficulty"])
    config = decode_config_param(params["config"])

    case Repo.get(Task, task_id) do
      nil ->
        {:ok, push_navigate(socket, to: "/tasks")}

      %Task{type: type} ->
        {:ok,
         assign(socket,
           live_view: resolve_live_view(type),
           params: params,
           current_user: current_user,
           full_screen?: true,
           live_action: live_action,
           difficulty: difficulty,
           config: config
         )}
    end
  end

  defp decode_config_param(nil), do: %{}
  defp decode_config_param(encoded_json) do
    encoded_json
    |> URI.decode()
    |> Jason.decode()
    |> case do
      {:ok, map} when is_map(map) -> map
      _ -> %{}
    end
  end

  defp resolve_live_view("math_operation"), do: BeamWeb.Tasks.MathOperationLive
  defp resolve_live_view("searching_for_an_answer"), do: BeamWeb.Tasks.SearchingForAnAnswerLive
  defp resolve_live_view("less_than_five"), do: BeamWeb.Tasks.LessThanFiveLive
  defp resolve_live_view("reverse_sequence"), do: BeamWeb.Tasks.ReverseSequenceLive
  defp resolve_live_view("code_of_symbols"), do: BeamWeb.Tasks.CodeOfSymbolsLive
  defp resolve_live_view("name_and_color"), do: BeamWeb.Tasks.NameAndColorLive
  defp resolve_live_view("follow_the_figure"), do: BeamWeb.Tasks.FollowTheFigureLive
  defp resolve_live_view("simon"), do: BeamWeb.Tasks.SimonLive
  defp resolve_live_view("searching_for_a_vowel"), do: BeamWeb.Tasks.SearchingForAVowelLive
  defp resolve_live_view("order_animals"), do: BeamWeb.Tasks.OrderAnimalsLive
  defp resolve_live_view(_), do: BeamWeb.Tasks.MathOperationLive

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
        "current_user" => @current_user,
        "full_screen?" => true,
        "config" => @config
      }
    )}
    """
  end
end

defmodule BeamWeb.DashboardController do
  use BeamWeb, :controller

  alias Beam.Accounts

  def index(conn, _params) do
    current_user = conn.assigns.current_user

    pacientes =
      if current_user.type in ["Admin", "Terapeuta"], do: Accounts.list_pacientes(), else: []

    terapeutas = Accounts.list_terapeutas()

    total_pacientes = length(pacientes)
    total_terapeutas = length(terapeutas)

    render(conn, "dashboard.html",
      pacientes: pacientes,
      terapeutas: terapeutas,
      total_pacientes: total_pacientes,
      total_terapeutas: total_terapeutas,
      current_user: current_user
    )
  end
end

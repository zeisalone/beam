defmodule BeamWeb.Plugs.AuthorizationPlugs do
  import Plug.Conn
  import Phoenix.Controller
  alias Beam.Accounts.User

  def ensure_admin(conn, _opts) do
    if conn.assigns.current_user && User.admin?(conn.assigns.current_user) do
      conn
    else
      conn
      |> put_flash(:error, "Denied Access.")
      |> redirect(to: "/")
      |> halt()
    end
  end

  def ensure_terapeuta(conn, _opts) do
    if conn.assigns.current_user && User.therapist?(conn.assigns.current_user) do
      conn
    else
      conn
      |> put_flash(:error, "Denied Access.")
      |> redirect(to: "/")
      |> halt()
    end
  end

  def ensure_paciente(conn, _opts) do
    if conn.assigns.current_user && User.paciente?(conn.assigns.current_user) do
      conn
    else
      conn
      |> put_flash(:error, "Denied Access.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end

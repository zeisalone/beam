defmodule BeamWeb.PageController do
  use BeamWeb, :controller

  def home(conn, _params) do
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/welcome")
    else
      render(conn, :home, layout: false)
    end
  end
end

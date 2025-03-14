defmodule Beam.Repo do
  use Ecto.Repo,
    otp_app: :beam,
    adapter: Ecto.Adapters.Postgres
end

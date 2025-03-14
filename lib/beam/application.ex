defmodule Beam.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BeamWeb.Telemetry,
      Beam.Repo,
      {DNSCluster, query: Application.get_env(:beam, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Beam.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Beam.Finch},
      # Start a worker by calling: Beam.Worker.start_link(arg)
      # {Beam.Worker, arg},
      # Start to serve requests, typically the last entry
      BeamWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Beam.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BeamWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

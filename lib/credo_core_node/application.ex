defmodule CredoCoreNode.Application do
  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    Mnesia.Repo.setup()

    # Define workers and child supervisors to be supervised
    children = [
      # Start the endpoint when the application starts
      supervisor(CredoCoreNodeWeb.Endpoint, []),
      worker(CredoCoreNode.Workers.ConnectionManager, [60_000]),
      worker(CredoCoreNode.Workers.BlockProposer, []),
      worker(CredoCoreNode.Workers.GarbageCollector, []),
      worker(CredoCoreNode.Scheduler, [])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CredoCoreNode.Supervisor]

    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    CredoCoreNodeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

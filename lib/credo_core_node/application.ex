defmodule CredoCoreNode.Application do
  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    setup_mnesia()

    # Define workers and child supervisors to be supervised
    children = [
      # Start the endpoint when the application starts
      supervisor(CredoCoreNodeWeb.Endpoint, [])
      # Start your own worker by calling: CredoCoreNode.Worker.start_link(arg1, arg2, arg3)
      # worker(CredoCoreNode.Worker, [arg1, arg2, arg3]),
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

  # TODO: move Mnesia initialization logic to a separate module/folder
  defp setup_mnesia() do
    :mnesia.create_schema([node()])
    :mnesia.start()

    :mnesia.create_table(:known_nodes, [attributes: [:url, :last_active_at]])
  end
end

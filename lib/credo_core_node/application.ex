defmodule CredoCoreNode.Application do
  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    setup_leveldb()

    Mnesia.Repo.setup()

    # Define workers and child supervisors to be supervised
    children =
      [
        # Start the endpoint when the application starts
        supervisor(CredoCoreNodeWeb.Endpoint, [])
      ]
      |> background_workers()

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

  defp setup_leveldb do
    Enum.each(["/leveldb", "/leveldb/blocks", "/leveldb/pending_blocks"], fn path ->
      File.mkdir("#{File.cwd!()}#{path}")
    end)
  end

  defp background_workers(children) do
    import Supervisor.Spec, only: [worker: 2, supervisor: 2]

    if Application.get_env(:credo_core_node, CredoCoreNode.Workers, [])[:enabled] do
      # Start the background workers
      children ++
        [
          worker(CredoCoreNode.Workers.ConnectionManager, [60_000]),
          worker(CredoCoreNode.Workers.BlockSyncer, []),
          worker(CredoCoreNode.Workers.DepositRecognizer, []),
          worker(CredoCoreNode.Workers.GarbageCollector, []),
          worker(CredoCoreNode.Workers.IpManager, []),
          worker(CredoCoreNode.Workers.MineOperator, []),
          worker(CredoCoreNode.Workers.Slasher, []),
          worker(CredoCoreNode.Scheduler, [])
        ]
    else
      children
    end
  end
end

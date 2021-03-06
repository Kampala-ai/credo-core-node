defmodule CredoCoreNode.Application do
  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    setup_leveldb()

    Mnesia.Repo.setup()

    maybe_load_genesis_block()

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
    Enum.each(
      ["/leveldb", "/leveldb/blocks", "/leveldb/pending_blocks", "/leveldb/state"],
      fn path ->
        File.mkdir("#{File.cwd!()}#{path}")
      end
    )
  end

  defp maybe_load_genesis_block do
    :timer.sleep(100)

    unless CredoCoreNode.Blockchain.get_block_by_number(0),
      do: CredoCoreNode.Blockchain.load_genesis_block()
  end

  defp background_workers(children) do
    if Application.get_env(:credo_core_node, CredoCoreNode.Workers, [])[:enabled] do
      # Start the background workers
      children ++
        [
          CredoCoreNode.Scheduler,
          CredoCoreNode.Workers
        ]
    else
      children
    end
  end
end

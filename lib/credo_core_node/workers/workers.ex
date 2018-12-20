defmodule CredoCoreNode.Workers do
  @moduledoc """
  Supervisor for all background workers using `:one_for_one` strategy.
  """

  use Supervisor

  import Supervisor.Spec, only: [worker: 2]

  alias CredoCoreNode.Workers.ConnectionManager
  alias CredoCoreNode.Workers.BlockSyncer
  alias CredoCoreNode.Workers.DepositRecognizer
  alias CredoCoreNode.Workers.GarbageCollector
  alias CredoCoreNode.Workers.IpManager
  alias CredoCoreNode.Workers.MineOperator
  alias CredoCoreNode.Workers.Slasher

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_) do
    children = [
      worker(ConnectionManager, [60_000]),
      worker(BlockSyncer, []),
      worker(DepositRecognizer, []),
      worker(GarbageCollector, []),
      worker(IpManager, []),
      worker(MineOperator, []),
      worker(Slasher, [])
    ]

    Supervisor.init(children, strategy: :one_for_one, name: CredoCoreNode.WorkersSupervisor)
  end
end

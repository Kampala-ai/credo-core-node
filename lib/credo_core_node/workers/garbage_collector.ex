defmodule CredoCoreNode.Workers.GarbageCollector do
  use GenServer

  require Logger

  import Process, only: [send_after: 3]

  alias CredoCoreNode.{Blockchain, Pool}

  @default_interval 60_000
  @recency_length 60

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    Logger.info("Initializing the garbage collector...")

    state = %{interval: Keyword.get(opts, :interval, @default_interval)}

    schedule_collect_garbage(state.interval)

    {:ok, state}
  end

  def handle_info(:collect_garbage, state) do
    Logger.info("Collecting garbage...")

    schedule_collect_garbage(state.interval)

    collect_pending_block_garbage()

    collect_pending_transaction_garbage()

    {:noreply, state}
  end

  def collect_pending_block_garbage do
    Pool.list_pending_blocks()
    |> Enum.filter(&(&1.number < Blockchain.last_irreversible_block_number()))
    |> Enum.each(fn block -> Pool.delete_pending_block(block) end)
  end

  def collect_pending_transaction_garbage do
    Enum.each(recent_irreversible_blocks(), fn block ->
      Enum.each(Blockchain.list_transactions(block), fn transaction ->
        case Pool.get_pending_transaction(transaction.hash) do
          nil ->
            :ok

          pending_transaction ->
            Pool.delete_pending_transaction(pending_transaction)
        end
      end)
    end)
  end

  defp recent_irreversible_blocks do
    Enum.filter(
      Blockchain.list_blocks(),
      &(&1.number < Blockchain.last_irreversible_block_number() &&
          &1.number > last_recent_irreversible_block_number())
    )
  end

  defp last_recent_irreversible_block_number(),
    do: Blockchain.last_irreversible_block_number() - @recency_length

  defp schedule_collect_garbage(interval) do
    send_after(self(), :collect_garbage, interval)
  end
end

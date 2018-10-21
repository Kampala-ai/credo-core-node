defmodule CredoCoreNode.Workers.DepositRecognizer do
  use GenServer

  require Logger

  import Process, only: [send_after: 3]

  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Mining.Deposit

  def start_link(interval \\ 120_000) do
    GenServer.start_link(__MODULE__, %{last_processed_block: nil, interval: interval}, name: __MODULE__)
  end

  def init(%{interval: interval} = state) do
    Logger.info("Initializing the deposit recognizer...")

    state =
      %{state | last_processed_block: Blockchain.last_block()} #TODO: Implement a more robust way of initially setting the last processed block.

    schedule_recognize_deposits(interval)

    {:ok, state}
  end

  def handle_info(:recognize_deposits, %{last_processed_block: last_processed_block, interval: interval} = state) do
    schedule_recognize_deposits(interval)

    processable_blocks =
      Blockchain.list_blocks()
      |> Enum.filter(&(&1.number > last_processed_block.number))
      |> Enum.filter(&(&1.number < last_finalized_block_number()))

    processable_blocks
    |> Enum.each(fn block -> Deposit.maybe_recognize_deposits(block) end)

    last_processed_block =
      processable_blocks
      |> Enum.sort(&(&1.number))
      |> List.first()

    state =
      %{state | last_processed_block: last_processed_block}

    {:ok, state}
  end

  defp last_finalized_block_number, do: last_confirmed_block_number() - Blockchain.finalization_threshold()
  defp last_confirmed_block_number, do: Blockchain.last_block().number

  defp schedule_recognize_deposits(interval) do
    send_after(self(), :recognize_deposits, interval)
  end
end
defmodule CredoCoreNode.Workers.Slasher do
  use GenServer

  require Logger

  import Process, only: [send_after: 3]

  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Mining.Slash

  def start_link(interval \\ 240_000) do
    GenServer.start_link(__MODULE__, %{last_processed_block: nil, interval: interval}, name: __MODULE__)
  end

  def init(%{interval: interval} = state) do
    Logger.info("Initializing the slasher...")

    state =
      %{state | last_processed_block: Blockchain.last_block()} #TODO: Implement a more robust way of initially setting the last processed block.

    schedule_slash_miners(interval)

    {:ok, state}
  end

  def handle_info(:slash_miners, %{last_processed_block: last_processed_block, interval: interval} = state) do
    schedule_slash_miners(interval)

    processable_blocks =
      Blockchain.list_blocks()
      |> Enum.filter(&(&1.number > last_processed_block.number))
      |> Enum.filter(&(&1.number < Blockchain.last_finalized_block_number()))

    processable_blocks
    |> Enum.each(fn block -> Slash.maybe_slash_miners(block) end)

    last_processed_block =
      processable_blocks
      |> Enum.sort(&(&1.number > &2.number))
      |> List.first()

    state =
      %{state | last_processed_block: last_processed_block}

    {:ok, state}
  end

  defp schedule_slash_miners(interval) do
    send_after(self(), :slash_miners, interval)
  end
end
defmodule CredoCoreNode.Workers.Slasher do
  use GenServer

  require Logger

  import Process, only: [send_after: 3]

  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Mining.Slash

  def start_link(interval \\ 240_000) do
    GenServer.start_link(
      __MODULE__,
      %{last_processed_block: nil, interval: interval},
      name: __MODULE__
    )
  end

  def init(%{interval: interval} = state) do
    Logger.info("Initializing the slasher...")

    # TODO: Implement a more robust way of initially setting the last processed block.
    state = %{state | last_processed_block: Blockchain.last_block()}

    schedule_slash_miners(interval)

    {:ok, state}
  end

  def handle_info(
        :slash_miners,
        %{last_processed_block: last_processed_block, interval: interval} = state
      ) do
    schedule_slash_miners(interval)

    last_processed_block_number =
      if last_processed_block, do: last_processed_block.number, else: 0

    processable_blocks = Blockchain.list_processable_blocks(last_processed_block_number)

    processable_blocks
    |> Enum.each(fn block -> Slash.maybe_slash_miners(block) end)

    last_processed_block = Blockchain.last_processed_block(processable_blocks)

    state = %{state | last_processed_block: last_processed_block}

    {:noreply, state}
  end

  defp schedule_slash_miners(interval) do
    send_after(self(), :slash_miners, interval)
  end
end

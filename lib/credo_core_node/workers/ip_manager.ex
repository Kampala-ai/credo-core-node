defmodule CredoCoreNode.Workers.IpManager do
  use GenServer

  require Logger

  import Process, only: [send_after: 3]

  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Mining.Ip

  @default_interval 240_000

  def start_link(opts \\ []) do
    GenServer.start_link(
      __MODULE__,
      %{last_processed_block: nil, interval: @default_interval},
      name: __MODULE__
    )
  end

  def init(%{interval: interval} = state) do
    Logger.info("Initializing the ip manager...")

    # TODO: Implement a more robust way of initially setting the last processed block.
    state = %{state | last_processed_block: Blockchain.last_block()}

    schedule_update_miner_ips(interval)

    {:ok, state}
  end

  def handle_info(
        :update_miner_ips,
        %{last_processed_block: last_processed_block, interval: interval} = state
      ) do
    schedule_update_miner_ips(interval)

    last_processed_block_number =
      if last_processed_block, do: last_processed_block.number, else: 0

    processable_blocks = Blockchain.list_processable_blocks(last_processed_block_number)

    processable_blocks
    |> Enum.each(fn block -> Ip.maybe_update_miner_ips(block) end)

    last_processed_block = Blockchain.last_processed_block(processable_blocks)

    state = %{state | last_processed_block: last_processed_block}

    {:noreply, state}
  end

  defp schedule_update_miner_ips(interval) do
    send_after(self(), :update_miner_ips, interval)
  end
end

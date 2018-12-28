defmodule CredoCoreNode.Workers.Slasher do
  use GenServer

  require Logger

  import Process, only: [send_after: 3]

  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Mining.Slash
  alias CredoCoreNode.Adapters.BlockchainAdapter
  alias CredoCoreNode.Adapters.SlashAdapter

  @default_interval 240_000
  @blockchain Application.get_env(:credo_core_node, BlockchainAdapter, Blockchain)
  @slash Application.get_env(:credo_core_node, SlashAdapter, Slash)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    Logger.info("Initializing the slasher...")

    # TODO: Implement a more robust way of initially setting the last processed block.
    state = %{
      interval: Keyword.get(opts, :interval, @default_interval),
      last_processed_block: @blockchain.last_block()
    }

    schedule_slash_miners(state.interval)

    {:ok, state}
  end

  def handle_info(
        :slash_miners,
        %{last_processed_block: last_processed_block, interval: interval} = state
      ) do
    schedule_slash_miners(interval)

    last_processed_block_number =
      if last_processed_block, do: last_processed_block.number, else: 0

    processable_blocks = @blockchain.list_processable_blocks(last_processed_block_number)

    processable_blocks
    |> Enum.each(fn block -> @slash.maybe_apply_slashes(block) end)

    last_processed_block = @blockchain.last_processed_block(processable_blocks)

    state = %{state | last_processed_block: last_processed_block}

    {:noreply, state}
  end

  def handle_call(:ping, _, state) do
    {:reply, :pong, state}
  end

  defp schedule_slash_miners(interval) do
    send_after(self(), :slash_miners, interval)
  end
end

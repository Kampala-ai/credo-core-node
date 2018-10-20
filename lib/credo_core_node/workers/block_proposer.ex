defmodule CredoCoreNode.Workers.BlockProposer do
  use GenServer

  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Blockchain.BlockValidator
  alias CredoCoreNode.Pool
  alias CredoCoreNode.Mining

  require Logger

  @block_proposal_timeout 10000

  def start_link() do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    Logger.info("Initializing the block proposer...")

    Blockchain.last_block()
    |> maybe_propose_next_block()

    {:ok, state}
  end

  @doc """
  Proposes the next block if its the node's turn.

  To be called after a block is confirmed.
  """
  def maybe_propose_next_block(confirmed_block, retry_count \\ 0) do
    if Mining.is_miner?() do
      if get_next_block_proposer(confirmed_block, retry_count) == Mining.get_own_miner() do
        Logger.info("Proposing block...")

        Pool.get_batch_of_pending_transactions()
        |> add_tx_fee_block_proposer_reward_transaction()
        |> Pool.generate_pending_block()
        |> broadcast_block_to_miners()
      else
        wait_for_block_from_selected_block_proposer(confirmed_block, retry_count)
      end
    end
  end

  @doc """
  Adds a transaction to pay transaction fees to the block proposer.
  """
  def add_tx_fee_block_proposer_reward_transaction(transactions) do
    tx_fees_sum =
      Pool.get_pending_transaction_fees_sum(transactions)

    miner =
      Mining.get_own_miner()

    private_key = "" # TODO: set private key
    attrs = %{nonce: 0, to: miner.address, value: tx_fees_sum, fee: 0, data: "{\"tx_type\" : \"#{Blockchain.coinbase_tx_type()}\"}"}

    {:ok, tx} =
      Pool.generate_pending_transaction(private_key, attrs)

    transactions ++ [tx]
  end

  @doc """
  Gets the next block proposer.
  """
  def get_next_block_proposer(last_block, retry_count) do
    miners =
      Mining.list_miners()
      |> Enum.sort(&(&1.address >= &2.address))

    # TODO: implement a more memory-efficient weighting mechanism.
    miner_addresses =
      for miner <- miners do
        index_count = round(miner.stake_amount * miner.participation_rate)

        for _ <- 0..index_count do
          miner.address
        end
      end
      |> Enum.concat

    number = last_block.number + 1

    # Seed rand with the current block number and the retry count to produce a deterministic, pseudorandom result.
    :rand.seed(:exsplus, {101, retry_count, number})

    index =
      Enum.random(1..length(miner_addresses))

    miner_addresses
    |> Enum.at(index)
    |> Mining.get_miner()
  end

  @doc """
  Broadcasts a block to miners
  """
  def broadcast_block_to_miners(_block) do
  end

  @doc """
  This will wait, until a specified timeout, for a block to be proposed and received by the selected block proposer.
  If a new candidate block is not received by the timeout, a new block proposer will be selected.

  This is needed in case the selected block proposer is offline or otherwise unresponsive.
  """
  def wait_for_block_from_selected_block_proposer(confirmed_block, retry_count) do
    Logger.info("Waiting for block...")
    :timer.sleep(@block_proposal_timeout)

    if (block = Blockchain.get_block_by_number(confirmed_block.number + 1)) do
      BlockValidator.validate_block(block)
    else
      maybe_propose_next_block(confirmed_block, retry_count + 1)
    end
  end
end
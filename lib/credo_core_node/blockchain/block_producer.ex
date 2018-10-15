defmodule CredoCoreNode.Blockchain.BlockProducer do
  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Pool
  alias CredoCoreNode.Validation

  @doc """
  Produces the next block if its the node's turn.

  To be called after a block is confirmed.
  """
  def maybe_produce_next_block(confirmed_block) do
    if Validation.is_validator?() do
      if get_next_block_producer(confirmed_block) == Validation.get_own_validator() do
        Pool.get_batch_of_pending_transactions()
        |> add_tx_fee_block_producer_reward_transaction()
        |> Blockchain.generate_block()
        |> broadcast_block_to_validators()
      else
        wait_for_block_from_selected_block_producer()
      end
    end
  end

  @doc """
  Adds a transaction to pay transaction fees to the block producer.
  """
  def add_tx_fee_block_producer_reward_transaction(transactions) do
    tx_fees_sum =
      Pool.get_pending_transaction_fees_sum(transactions)
  end

  @doc """
  Gets the next block producer.

  #TODO weight by stake size and participation rate.
  """
  def get_next_block_producer(last_block) do
    number = last_block.number + 1

    # Seed rand with the current block number to produce a deterministic, pseudorandom result.
    :rand.seed(:exsplus, {101, 102, number})

    index =
      Enum.random(1..Validation.count_validators())

    Validation.list_validators()
    |> Enum.sort( &(&1.address >= &2.address) )
    |> Enum.at(index)
  end

  @doc """
  Broadcasts a block to validators
  """
  def broadcast_block_to_validators(block) do
  end

  @doc """
  This will wait, until a specified timeout, for a block to be produced and received by the selected block producer.
  If a new candidate block is not received by the timeout, a new block producer will be selected.

  This is needed in case the selected block producer is offline or otherwise unresponsive.
  """
  def wait_for_block_from_selected_block_producer do
  end
end
defmodule CredoCoreNode.Blockchain.BlockProposer do
  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Blockchain.BlockValidator
  alias CredoCoreNode.Pool
  alias CredoCoreNode.Validation

  require Logger

  @block_proposal_timeout 10000

  @doc """
  Proposes the next block if its the node's turn.

  To be called after a block is confirmed.
  """
  def maybe_propose_next_block(confirmed_block, retry_count \\ 0) do
    if Validation.is_validator?() do
      if get_next_block_proposer(confirmed_block, retry_count) == Validation.get_own_validator() do
        Logger.info("Proposing block...")

        Pool.get_batch_of_pending_transactions()
        |> add_tx_fee_block_proposer_reward_transaction()
        |> Pool.generate_pending_block()
        |> broadcast_block_to_validators()
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

    validator =
      Validation.get_own_validator()

    private_key = "" # TODO: set private key
    attrs = %{nonce: 0, to: validator.address, value: tx_fees_sum, fee: 0, data: "{\"tx_type\" : \"#{Blockchain.coinbase_tx_type()}\"}"}

    {:ok, tx} =
      Pool.generate_pending_transaction(private_key, attrs)

    transactions ++ [tx]
  end

  @doc """
  Gets the next block proposer.
  """
  def get_next_block_proposer(last_block, retry_count) do
    validators =
      Validation.list_validators()
      |> Enum.sort(&(&1.address >= &2.address))

    # TODO: implement a more memory-efficient weighting mechanism.
    validator_addresses =
      for validator <- validators do
        index_count = round(validator.stake_amount * validator.participation_rate)

        for _ <- 0..index_count do
          validator.address
        end
      end
      |> Enum.concat

    number = last_block.number + 1

    # Seed rand with the current block number and the retry count to propose a deterministic, pseudorandom result.
    :rand.seed(:exsplus, {101, retry_count, number})

    index =
      Enum.random(1..length(validator_addresses))

    validator_addresses
    |> Enum.at(index)
    |> Validation.get_validator()
  end

  @doc """
  Broadcasts a block to validators
  """
  def broadcast_block_to_validators(_block) do
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
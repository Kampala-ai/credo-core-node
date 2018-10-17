defmodule CredoCoreNode.Blockchain.BlockValidator do
  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Validation.SecurityDeposits
  alias CredoCoreNode.Validation.ValidatorIpManager
  alias CredoCoreNode.Validation.VoteManager

  @finalization_threshold 12
  @min_txs_per_block 0
  @max_txs_per_block 250
  @max_data_length 50000

  @doc """
  Validates a block.

  If any validation fails, the candidate block is marked as invalid.
  """
  def validate_block(block) do
    is_valid =
      validate_previous_hash(block) &&
      validate_format(block) &&
      validate_transaction_count(block) &&
      validate_transaction_data_length(block) &&
      validate_security_deposits(block) &&
      validate_validator_updates(block) &&
      validate_block_finalization(block) &&
      validate_coinbase_transaction(block) &&
      validate_network_consensus(block)

    if is_valid do
      {:ok, block}
    else
      Blockchain.mark_block_as_invalid(block)

      {:error, block}
    end
  end

  @doc """
  Validates the previous block hash identifies a validated block with the right block number.
  """
  def validate_previous_hash(block) do
    prev_block = Blockchain.get_block(block.prev_hash)

    not is_nil(prev_block) && prev_block.number == block.number - 1
  end

  @doc """
  Validates block format.
  """
  def validate_format(block) do
  end

  @doc """
  Validates block transaction count.

  TODO: add virtual field or other method of easily retrieving block transactions.
  """
  def validate_transaction_count(block) do
    len = length(block.transactions)

    len > @min_txs_per_block && len <= @max_txs_per_block
  end

  @doc """
  Validates transaction data length.

  This is to prevent a denial of service attack by a block producer adding an overly large data field.
  """
  def validate_transaction_data_length(block) do
    for tx <- block.transactions do
      length(tx.data) <= @max_data_length
    end
    |> Enum.reduce(true, &(&1 && &2))
  end

  @doc """
  Validates security deposits.
  """
  def validate_security_deposits(block) do
    SecurityDeposits.maybe_process_security_deposits(block.body)
  end

  @doc """
  Validate validator updates.
  """
  def validate_validator_updates(block) do
    ValidatorIpManager.maybe_validate_validator_ip_update_transactions(block.body)
  end

  @doc """
  Validate finalization condition.
  """
  def validate_block_finalization(block) do
    last_finalized_block =
      Blockchain.list_blocks()
      |> Enum.filter(&(&1.number == block.number - @finalization_threshold))
      |> List.first()

    # Check that the current block is in a chain of blocks containing the last finalized block.
  end

  @doc """
  Validate that there is only 1 coinbase transaction and that the coinbase transaction pays itself the sum of transactions fees of other transactions in the block.
  """
  def validate_coinbase_transaction(block) do
    [coinbase_tx] = coinbase_txs =
      block.transactions
      |> Enum.filter(&(Poison.decode!(&1.data)["tx_type"] == Blockchain.coinbase_tx_type()))

    non_coinbase_tx_fees_sum =
      Pool.get_pending_transaction_fees_sum(block.transactions -- coinbase_tx)

    length(coinbase_txs) == 1 && coinbase_tx.fee == non_coinbase_tx_fees_sum
  end

  @doc """
  Validate network consensus.
  """
  def validate_network_consensus(block) do
    VoteManager.vote(block)
  end
end
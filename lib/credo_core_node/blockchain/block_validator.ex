defmodule CredoCoreNode.Blockchain.BlockValidator do
  alias CredoCoreNode.{Blockchain, Pool, Mining}
  alias CredoCoreNode.Mining.{Coinbase, DepositWithdrawal}

  @min_txs_per_block 1
  @max_txs_per_block 250
  @max_data_length 50000

  def validate_block(block) do
    is_valid =
      validate_previous_hash(block) &&
      validate_format(block) &&
      validate_transaction_count(block) &&
      validate_transaction_data_length(block) &&
      validate_deposit_withdrawals(block) &&
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

  def validate_previous_hash(%{number: number} = block) when number == 0, do: true
  def validate_previous_hash(block) do
    prev_block = Blockchain.get_block(block.prev_hash)

    not is_nil(prev_block) && prev_block.number == block.number - 1
  end

  def validate_format(block) do
    not is_nil(block.hash) &&
    not is_nil(block.prev_hash) &&
    not is_nil(block.number) &&
    not is_nil(block.state_root) &&
    not is_nil(block.receipt_root) &&
    not is_nil(block.tx_root)
  end

  def validate_transaction_count(block) do
    len = length(block.transactions)

    len >= @min_txs_per_block && len <= @max_txs_per_block
  end

  def validate_transaction_data_length(block) do
    res =
      Enum.map block.transactions, fn tx ->
        String.length(tx.data) <= @max_data_length
      end

    Enum.reduce(res, true, &(&1 && &2))
  end

  def validate_deposit_withdrawals(block) do
    DepositWithdrawal.validate_deposit_withdrawals(block)
  end

  def validate_block_finalization(block) do
    _last_finalized_block =
      Blockchain.list_blocks()
      |> Enum.filter(&(&1.number == block.number - Blockchain.finalization_threshold()))
      |> List.first()

    true # Check that the current block is in a chain of blocks containing the last finalized block.
  end

  def validate_coinbase_transaction(block) do
    coinbase_txs =
      Coinbase.get_coinbase_txs(block)

    length(coinbase_txs) == 1 && Coinbase.tx_fee_sums_match(block, coinbase_txs)
  end

  def validate_network_consensus(block) do
    {:ok, confirmed_block}
      = Mining.start_voting(block)

    block.hash == confirmed_block.hash
  end
end
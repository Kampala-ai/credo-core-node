defmodule CredoCoreNode.Blockchain.BlockValidator do
  alias CredoCoreNode.{Blockchain, Pool, Mining}
  alias CredoCoreNode.Mining.{Coinbase, DepositWithdrawal}

  alias Decimal, as: D

  @min_txs_per_block 1
  @max_txs_per_block 250
  @max_data_length 50000
  @max_value_transfer_per_tx D.new(1_000_000)
  @max_value_transfer_per_block D.new(10_000_000)
  @max_value_transfer_per_block_chain_segment D.new(50_000_000)
  @block_chain_segment_length 12

  def validate_block(block) do
    is_valid =
      validate_previous_hash(block) && validate_format(block) && validate_transaction_count(block) &&
        validate_transaction_data_length(block) && validate_transaction_amounts(block) &&
        validate_transaction_are_unmined(block) && validate_deposit_withdrawals(block) &&
        validate_block_irreversibility(block) && validate_coinbase_transaction(block) &&
        validate_value_transfer_limits(block) && validate_network_consensus(block)

    if is_valid do
      {:ok, block}
    else
      Blockchain.mark_block_as_invalid(block)

      {:error, block}
    end
  end

  def validate_previous_hash(%{number: number} = _block) when number == 0, do: true

  def validate_previous_hash(block) do
    prev_block = Blockchain.get_block(block.prev_hash)

    not is_nil(prev_block) && prev_block.number == block.number - 1
  end

  def validate_format(block) do
    not is_nil(block.hash) && not is_nil(block.prev_hash) && not is_nil(block.number) &&
      not is_nil(block.state_root) && not is_nil(block.receipt_root) && not is_nil(block.tx_root)
  end

  def validate_transaction_count(block) do
    len = length(Pool.list_pending_transactions(block))

    len >= @min_txs_per_block && len <= @max_txs_per_block
  end

  def validate_transaction_data_length(block) do
    res =
      Enum.map(Pool.list_pending_transactions(block), fn tx ->
        String.length(tx.data) <= @max_data_length
      end)

    Enum.reduce(res, true, &(&1 && &2))
  end

  def validate_transaction_amounts(block) do
    res =
      Enum.map(Pool.list_pending_transactions(block), fn tx ->
        Pool.is_tx_from_balance_sufficient?(tx) || Coinbase.is_coinbase_tx(tx)
      end)

    Enum.reduce(res, true, &(&1 && &2))
  end

  def validate_transaction_are_unmined(block) do
    # TODO: replace with more efficient implementation.
    res =
      Enum.map(Pool.list_pending_transactions(block), fn tx ->
        Pool.is_tx_unmined?(tx, block)
      end)

    Enum.reduce(res, true, &(&1 && &2))
  end

  def validate_deposit_withdrawals(block) do
    DepositWithdrawal.validate_deposit_withdrawals(block)
  end

  def validate_block_irreversibility(block) do
    _last_irreversible_block =
      Blockchain.list_blocks()
      |> Enum.filter(&(&1.number == block.number - Blockchain.irreversibility_threshold()))
      |> List.first()

    # Check that the current block is in a chain of blocks containing the last irreversible block.
    true
  end

  def validate_coinbase_transaction(block) do
    coinbase_txs = Coinbase.get_coinbase_txs(block)

    length(coinbase_txs) == 1 && Coinbase.tx_fee_sums_match(block, coinbase_txs)
  end

  def validate_value_transfer_limits(block) do
    txs = Pool.list_pending_transactions(block)

    validate_per_tx_value_transfer_limits(txs) && validate_per_block_value_transfer_limits(txs)
  end

  def validate_per_tx_value_transfer_limits(txs) do
    res =
      Enum.map(txs, fn tx ->
        D.cmp(tx.value, @max_value_transfer_per_tx) != :gt
      end)

    Enum.reduce(res, true, &(&1 && &2))
  end

  def validate_per_block_value_transfer_limits(txs) do
    D.cmp(Pool.sum_pending_transaction_values(txs), @max_value_transfer_per_block) != :gt
  end

  def validate_per_block_chain_segment_value_transfer_limits(block) do
    pending_block_value = Pool.sum_pending_transaction_values(block)

    Blockchain.list_preceding_blocks(block)
    |> Enum.take(@block_chain_segment_length)
    |> Enum.reduce(pending_block_value, fn b, acc ->
      D.add(Blockchain.sum_transaction_values(b), acc)
    end)
    |> D.cmp(@max_value_transfer_per_block_chain_segment) != :gt
  end

  def validate_network_consensus(block) do
    {:ok, confirmed_block} = Mining.start_voting(block)

    block.hash == confirmed_block.hash
  end
end

defmodule CredoCoreNode.Blockchain.BlockValidator do
  alias CredoCoreNode.{Blockchain, Pool, Mining}
  alias CredoCoreNode.Blockchain.{Block, Transaction}
  alias CredoCoreNode.Mining.{Coinbase, DepositWithdrawal}
  alias CredoCoreNode.Pool.{PendingBlock, PendingTransaction}
  alias MerklePatriciaTree.Trie

  alias Decimal, as: D

  defdelegate valid_coinbase_transaction?(block), to: Coinbase
  defdelegate valid_deposit_withdrawals?(block), to: DepositWithdrawal

  @behaviour CredoCoreNode.Adapters.BlockValidatorAdapter

  @min_txs_per_block 1
  @max_txs_per_block 250
  @max_data_length 50000
  @max_value_transfer_per_tx D.new(1_000_000)
  @max_value_transfer_per_block D.new(10_000_000)
  @max_value_transfer_per_block_chain_segment D.new(50_000_000)
  @block_chain_segment_length 12

  def valid_block?(block, skip_network_consensus_validation \\ false) do
    is_valid =
      valid_block_hash?(block, block.hash) && valid_prev_hash?(block) && valid_format?(block) &&
        valid_transaction_count?(block) && valid_transaction_data_length?(block) &&
        valid_transaction_amounts?(block) && valid_transaction_are_unmined?(block) &&
        valid_deposit_withdrawals?(block) && valid_block_irreversibility?(block) &&
        valid_coinbase_transaction?(block) && valid_value_transfer_limits?(block)

    is_valid =
      case skip_network_consensus_validation do
        true -> is_valid
        false -> is_valid && valid_network_consensus?(block)
      end

    if is_valid do
      {:ok, block}
    else
      Blockchain.mark_block_as_invalid(block)

      {:error, block}
    end
  end

  def valid_prev_hash?(%{number: number} = _block) when number == 0, do: true

  def valid_prev_hash?(block) do
    prev_block = Blockchain.get_block(block.prev_hash)

    not is_nil(prev_block) && prev_block.number == (block.number || 0) - 1
  end

  def valid_format?(block) do
    not is_nil(block.hash) && not is_nil(block.prev_hash) && not is_nil(block.number) &&
      not is_nil(block.state_root) && not is_nil(block.receipt_root) && not is_nil(block.tx_root)
  end

  def valid_transaction_count?(block) do
    len = length(Blockchain.list_transactions(block))

    len >= @min_txs_per_block && len <= @max_txs_per_block
  end

  def valid_transaction_data_length?(block) do
    res =
      Enum.map(Blockchain.list_transactions(block), fn tx ->
        String.length(tx.data) <= @max_data_length
      end)

    Enum.reduce(res, true, &(&1 && &2))
  end

  def valid_transaction_amounts?(%{number: number}) when number == 0, do: true

  def valid_transaction_amounts?(block) do
    prev_block = Blockchain.get_block(block.prev_hash)

    res =
      Enum.map(Blockchain.list_transactions(block), fn tx ->
        Pool.is_tx_from_balance_sufficient?(tx, prev_block) || Coinbase.is_coinbase_tx?(tx)
      end)

    Enum.reduce(res, true, &(&1 && &2))
  end

  def valid_transaction_are_unmined?(block) do
    # TODO: replace with more efficient implementation.
    res =
      Enum.map(Blockchain.list_transactions(block), fn tx ->
        Pool.is_tx_unmined?(tx, block)
      end)

    Enum.reduce(res, true, &(&1 && &2))
  end

  def valid_block_irreversibility?(block) do
    _last_irreversible_block =
      Blockchain.list_blocks()
      |> Enum.filter(&(&1.number == block.number - Blockchain.irreversibility_threshold()))
      |> List.first()

    # Check that the current block is in a chain of blocks containing the last irreversible block.
    true
  end

  def valid_value_transfer_limits?(%{number: number}) when number == 0, do: true

  def valid_value_transfer_limits?(block) do
    txs = Blockchain.list_transactions(block)

    valid_per_tx_value_transfer_limits?(txs) && valid_per_block_value_transfer_limits?(txs)
  end

  def valid_per_tx_value_transfer_limits?(txs) do
    res =
      Enum.map(txs, fn tx ->
        D.cmp(tx.value, @max_value_transfer_per_tx) != :gt
      end)

    Enum.reduce(res, true, &(&1 && &2))
  end

  def valid_per_block_value_transfer_limits?(txs) do
    D.cmp(Pool.sum_pending_transaction_values(txs), @max_value_transfer_per_block) != :gt
  end

  def valid_per_block_chain_segment_value_transfer_limits?(%{number: number})
      when number < @block_chain_segment_length + 1,
      do: true

  def valid_per_block_chain_segment_value_transfer_limits?(block) do
    pending_block_value = Pool.sum_pending_transaction_values(block)

    Blockchain.list_preceding_blocks(block)
    |> Enum.take(@block_chain_segment_length)
    |> Enum.reject(&(&1.number == 0))
    |> Enum.reduce(pending_block_value, fn b, acc ->
      D.add(Blockchain.sum_transaction_values(b), acc)
    end)
    |> D.cmp(@max_value_transfer_per_block_chain_segment) != :gt
  end

  def valid_nonces?(block) do
    prev_block = Blockchain.get_block(block.prev_hash)

    res =
      Enum.map(Blockchain.list_transactions(block), fn tx ->
        Pool.valid_nonce?(tx, prev_block)
      end)

    Enum.reduce(res, true, &(&1 && &2))
  end

  # TODO: refactor block hash/body validation functions for better performance
  def valid_block_hash?(nil, _hash), do: false
  def valid_block_hash?(%{hash: blk_hash}, hash) when blk_hash != hash, do: false
  def valid_block_hash?(blk, hash), do: RLP.Hash.hex(blk) == hash

  def valid_block_body?(nil, _body), do: false

  def valid_block_body?(%Block{} = blk, body), do: valid_block_body?(blk, body, Transaction)

  def valid_block_body?(%PendingBlock{} = blk, body),
    do: valid_block_body?(blk, body, PendingTransaction)

  defp valid_block_body?(blk, body, tx_module) do
    try do
      txs =
        body
        |> ExRLP.decode()
        |> Enum.map(&tx_module.from_list(&1, type: :rlp_default))

      valid_block_transactions?(blk, txs, tx_module)
    rescue
      # Body is not properly RLP-encoded
      ArgumentError ->
        false
    end
  end

  defp valid_block_transactions?(_blk, [], _tx_module), do: false

  defp valid_block_transactions?(blk, txs, tx_module) when is_list(txs) do
    {:ok, tx_trie, _txs} =
      MerklePatriciaTree.DB.ETS.random_ets_db()
      |> Trie.new()
      |> MPT.Repo.write_list(tx_module, txs)

    tx_root = Base.encode16(tx_trie.root_hash)

    blk.tx_root == tx_root
  end

  defp valid_block_transactions?(_blk, _invalid_arg, _tx_module), do: false

  def valid_network_consensus?(block) do
    {:ok, confirmed_block} = Mining.start_voting(block, 0)

    block.hash == confirmed_block.hash
  end
end

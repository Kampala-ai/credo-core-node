defmodule CredoCoreNode.Mining.Coinbase do
  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Pool

  def get_coinbase_txs(txs) do
    Enum.filter(txs, & is_coinbase_tx(&1))
  end

  def is_coinbase_tx(tx) do
    Poison.decode!(tx.data)["tx_type"] == Blockchain.coinbase_tx_type()
  end

  def tx_fee_sums_match(block, txs) do
    [coinbase_tx] = txs

    non_coinbase_tx_fees_sum =
      Pool.sum_pending_transaction_fees(block.transactions -- coinbase_tx)

    coinbase_tx.fee == non_coinbase_tx_fees_sum
  end
end

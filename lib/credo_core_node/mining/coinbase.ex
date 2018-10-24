defmodule CredoCoreNode.Mining.Coinbase do
  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Mining
  alias CredoCoreNode.Pool

  def add_coinbase_tx(txs) when txs == [], do: []
  def add_coinbase_tx(txs) do
    {:ok, tx} =
      Pool.generate_pending_transaction("", %{ # TODO: set private key
        nonce: 0,
        to: Mining.my_miner().address,
        value: Pool.sum_pending_transaction_fees(txs),
        fee: 1.0,
        data: "{\"tx_type\" : \"#{Blockchain.coinbase_tx_type()}\"}"
      })

    txs ++ [tx]
  end

  def get_coinbase_txs(block) do
    block
    |> Pool.list_pending_transactions()
    |> Enum.filter(& is_coinbase_tx(&1))
  end

  def is_coinbase_tx(tx) do
    Poison.decode!(tx.data)["tx_type"] == Blockchain.coinbase_tx_type()
  end

  def tx_fee_sums_match(block, coinbase_txs) do
    [coinbase_tx] = coinbase_txs

    non_coinbase_tx_fees_sum =
      Pool.sum_pending_transaction_fees(Pool.list_pending_transactions(block) -- coinbase_tx)

    coinbase_tx.fee == non_coinbase_tx_fees_sum
  end
end

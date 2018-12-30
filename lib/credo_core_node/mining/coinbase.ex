defmodule CredoCoreNode.Mining.Coinbase do
  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Mining
  alias CredoCoreNode.Pool

  alias Decimal, as: D

  @behaviour CredoCoreNode.Adapters.CoinbaseAdapter

  def add_coinbase_tx(txs) when txs == [], do: []

  def add_coinbase_tx(txs) do
    # TODO: set private key
    {:ok, tx} =
      Pool.generate_pending_transaction("", %{
        nonce: Blockchain.last_confirmed_block_number() + 1,
        to: Mining.my_miner().address,
        value: Pool.sum_pending_transaction_fees(txs),
        fee: 1.0,
        data: Poison.encode!(%{tx_type: Blockchain.coinbase_tx_type()})
      })

    txs ++ [tx]
  end

  def valid_coinbase_transaction?(%{number: number}) when number == 0, do: true
  def valid_coinbase_transaction?(block) do
    coinbase_txs = get_coinbase_txs(block)

    valid_number_of_txs?(coinbase_txs) && valid_value?(block, coinbase_txs) && valid_to?(coinbase_txs)
  end

  def valid_number_of_txs?(coinbase_txs), do: length(coinbase_txs) == 1

  def valid_value?(block, coinbase_txs), do: tx_fee_sums_match?(block, coinbase_txs)

  def valid_to?(coinbase_txs) do
    to =
      List.first(coinbase_txs).to

    !is_nil(Mining.get_miner(to))
  end

  def get_coinbase_txs(block) do
    block
    |> Pool.list_pending_transactions()
    |> Enum.filter(&is_coinbase_tx?(&1))
  end

  def is_coinbase_tx?(%{data: nil} = _tx), do: false
  def is_coinbase_tx?(%{data: data} = _tx) when not is_binary(data), do: false

  def is_coinbase_tx?(%{data: data} = tx) when is_binary(data) do
    try do
      tx.data =~ "tx_type" && Poison.decode!(tx.data)["tx_type"] == Blockchain.coinbase_tx_type()
    rescue
      Poison.SyntaxError -> false
    end
  end

  def tx_fee_sums_match?(block, coinbase_txs) do
    coinbase_tx = List.first(coinbase_txs)

    txs_minus_coinbase_tx =
      Pool.list_pending_transactions(block)
      |> Enum.filter(&(!is_coinbase_tx?(&1)))

    non_coinbase_tx_fees_sum = Pool.sum_pending_transaction_fees(txs_minus_coinbase_tx)

    D.cmp(coinbase_tx.value, non_coinbase_tx_fees_sum) == :eq
  end
end

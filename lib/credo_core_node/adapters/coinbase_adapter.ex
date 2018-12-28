defmodule CredoCoreNode.Adapters.CoinbaseAdapter do
  alias CredoCoreNode.Blockchain.{Block, Transaction}
  alias CredoCoreNode.Pool.{PendingBlock, PendingTransaction}

  @callback add_coinbase_tx(list(%PendingTransaction{})) :: list(%PendingTransaction{})

  @callback is_coinbase_tx?(%PendingTransaction{} | %Transaction{}) :: boolean()
  @callback tx_fee_sums_match?(%PendingBlock{} | %Block{}, list(%PendingTransaction{} | %Transaction{})) :: boolean()
end

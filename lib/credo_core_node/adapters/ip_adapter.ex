defmodule CredoCoreNode.Adapters.IpAdapter do
  alias CredoCoreNode.Blockchain.{Block, Transaction}
  alias CredoCoreNode.Pool.{PendingBlock, PendingTransaction}

  @callback maybe_update_miner_ip() :: %PendingTransaction{}
  @callback miner_ip_changed?() :: boolean()
  @callback construct_miner_ip_update_transaction(String.t(), String.t()) :: %PendingTransaction{}

  @callback is_miner_ip_update?(%Transaction{}) :: boolean()

  @callback maybe_apply_miner_ip_updates(%PendingBlock{} | %Block{}) :: list()
  @callback apply_miner_ip_updates(list(%Transaction{})) :: list()
end

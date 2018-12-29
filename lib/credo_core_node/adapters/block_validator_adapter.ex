defmodule CredoCoreNode.Adapters.BlockValidatorAdapter do
  alias CredoCoreNode.Blockchain.Block
  alias CredoCoreNode.Pool.{PendingBlock, PendingTransaction}

  @callback valid_block?(%PendingBlock{}, boolean()) :: boolean()
  @callback valid_prev_hash?(%PendingBlock{}) :: boolean()
  @callback valid_format?(%PendingBlock{}) :: boolean()
  @callback valid_transaction_count?(%PendingBlock{}) :: boolean()
  @callback valid_transaction_data_length?(%PendingBlock{}) :: boolean()
  @callback valid_transaction_amounts?(%PendingBlock{}) :: boolean()
  @callback valid_transaction_are_unmined?(%PendingBlock{}) :: boolean()
  @callback valid_deposit_withdrawals?(%PendingBlock{}) :: boolean()
  @callback valid_block_irreversibility?(%PendingBlock{}) :: boolean()
  @callback valid_coinbase_transaction?(%PendingBlock{}) :: boolean()
  @callback valid_value_transfer_limits?(%PendingBlock{}) :: boolean()
  @callback valid_per_tx_value_transfer_limits?(list(%PendingTransaction{})) :: boolean()
  @callback valid_per_block_value_transfer_limits?(list(%PendingTransaction{})) :: boolean()
  @callback valid_per_block_chain_segment_value_transfer_limits?(%PendingBlock{}) :: boolean()
  @callback valid_nonces?(%PendingBlock{}) :: boolean()
  @callback valid_block_hash?(%PendingBlock{} | %Block{} | nil, String.t()) :: boolean()
  @callback valid_block_body?(%PendingBlock{} | %Block{} | nil, String.t()) :: boolean()
  @callback valid_network_consensus?(%PendingBlock{}) :: boolean()
end

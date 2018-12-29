defmodule CredoCoreNode.Adapters.BlockchainAdapter do
  alias CredoCoreNode.Blockchain.{Block, BlockFragment, Transaction}
  alias CredoCoreNode.Pool.PendingBlock

  @callback coinbase_tx_type() :: String.t()
  @callback security_deposit_tx_type() :: String.t()
  @callback slash_tx_type() :: String.t()
  @callback update_miner_ip_tx_type() :: String.t()

  @callback irreversibility_threshold() :: integer()
  @callback last_irreversible_block_number() :: integer()
  @callback last_confirmed_block_number() :: integer()

  @callback list_transactions(%Block{} | nil) :: list(%Transaction{})
  @callback sum_transaction_values(%Block{} | list(%Transaction{})) :: Decimal.t()
  @callback sum_transaction_values(list(%Transaction{})) :: Decimal.t()
  @callback get_transaction(String.t()) :: %Transaction{}
  @callback write_transaction(map()) :: %Transaction{}
  @callback delete_transaction(%Transaction{}) :: %Transaction{}

  @callback list_block_fragments() :: list(%BlockFragment{})
  @callback get_block_fragment(String.t()) :: %BlockFragment{}
  @callback write_block_fragment(map()) :: %BlockFragment{}
  @callback delete_block_fragment(%BlockFragment{}) :: %BlockFragment{}

  @callback list_blocks() :: list(%Block{})
  @callback list_preceding_blocks(%Block{}) :: list(%Block{})
  @callback list_processable_blocks(integer()) :: list(%Block{})
  @callback last_processed_block(list(%Block{})) :: %Block{}
  @callback last_block() :: %Block{}
  @callback load_genesis_block() :: %Block{}
  @callback get_block(String.t()) :: %Block{}
  @callback get_block_by_number(integer()) :: %Block{}
  @callback write_block(%Block{}) :: %Block{}
  @callback write_block(map()) :: %Block{}
  @callback delete_block(%Block{}) :: %Block{}
  @callback propagate_block(%Block{}, list()) :: %Block{}

  @callback load_block_body(%Block{} | nil) :: %Block{} | nil
  @callback fetch_block_body(%PendingBlock{} | %Block{}, String.t(), atom()) ::
              %PendingBlock{} | %Block{} | nil
  @callback block_body_fetched?(%Block{}) :: boolean()

  @callback mark_block_as_invalid(%PendingBlock{}) :: %PendingBlock{}
end

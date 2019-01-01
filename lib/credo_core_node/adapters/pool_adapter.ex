defmodule CredoCoreNode.Adapters.PoolAdapter do
  alias CredoCoreNode.Blockchain.{Block, Transaction}
  alias CredoCoreNode.Pool.{PendingBlock, PendingBlockFragment, PendingTransaction}

  @callback list_pending_transactions(%PendingBlock{} | nil) :: list(%PendingBlock{})
  @callback get_batch_of_valid_pending_transactions() :: list(%PendingBlock{})
  @callback get_pending_transaction(String.t()) :: %PendingBlock{}
  @callback sum_pending_transaction_fees(list(%PendingBlock{})) :: Decimal.t()
  @callback sum_pending_transaction_values(list(%PendingBlock{}) | %PendingBlock{}) :: Decimal.t()
  @callback write_pending_transaction(map()) :: %PendingBlock{}
  @callback delete_pending_transaction(%PendingTransaction{}) :: %PendingTransaction{}
  @callback generate_pending_transaction(String.t(), map()) :: %PendingTransaction{}
  @callback propagate_pending_transaction(%PendingTransaction{}, list()) :: %PendingTransaction{}

  @callback list_pending_block_fragments() :: list(%PendingBlockFragment{})
  @callback get_pending_block_fragment(String.t()) :: %PendingBlockFragment{}
  @callback write_pending_block_fragment(map()) :: %PendingBlockFragment{}
  @callback delete_pending_block_fragment(%PendingBlockFragment{}) :: %PendingBlockFragment{}

  @callback list_pending_blocks(integer() | nil) :: list(%PendingBlock{})
  @callback get_pending_block(String.t()) :: %PendingBlock{}
  @callback get_block_by_number(integer()) :: %PendingBlock{}
  @callback write_pending_block(%PendingBlock{} | map()) :: %PendingBlock{}
  @callback delete_pending_block(%PendingBlock{}) :: %PendingBlock{}
  @callback generate_pending_block(list(%PendingTransaction{})) :: %PendingBlock{}
  @callback propagate_pending_block(%PendingBlock{}, list()) :: %PendingBlock{}

  @callback load_pending_block_body(%PendingBlock{} | nil) :: %PendingBlock{} | nil
  @callback fetch_pending_block_body(%PendingBlock{}, String.t(), atom()) :: %PendingBlock{}
  @callback pending_block_body_fetched?(%PendingBlock{}) :: boolean()

  @callback is_tx_unmined?(%PendingTransaction{} | %Transaction{}) :: boolean()
  @callback is_tx_unmined?(%PendingTransaction{} | %Transaction{}, %PendingBlock{} | %Block{}) ::
              boolean()
  @callback is_tx_from_balance_sufficient?(%PendingTransaction{} | %Transaction{}) :: boolean()
  @callback valid_tx?(%PendingTransaction{} | %Transaction{}) :: boolean()
  @callback invalid_tx?(%PendingTransaction{} | %Transaction{}) :: boolean()

  @callback get_transaction_from_address(%PendingTransaction{} | %Transaction{}) ::
              %PendingTransaction{} | %Transaction{}
  @callback outgoing_tx_count_for_from_address(%PendingTransaction{} | %Transaction{}, %Block{}) ::
              integer()
  @callback sign_message(String.t(), String.t()) :: String.t()
end

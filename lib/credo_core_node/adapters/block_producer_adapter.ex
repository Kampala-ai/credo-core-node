defmodule CredoCoreNode.Adapters.BlockProducerAdapter do
  alias CredoCoreNode.Blockchain.Block
  alias CredoCoreNode.Pool.{PendingBlock, PendingTransaction}
  alias CredoCoreNode.Mining.Miner

  @callback get_produced_block(%PendingBlock{} | %Block{}) :: %PendingBlock{}

  @callback get_next_block_producer(%PendingBlock{} | %Block{}, integer()) :: %Miner{}
  @callback is_your_turn?(%PendingBlock{}, integer()) :: boolean()

  @callback produce_block(list(%PendingTransaction{}) | nil) :: %PendingBlock{}

  @callback wait_for_block(%PendingBlock{} | %Block{}, integer()) :: boolean() | {:error, atom()}
end

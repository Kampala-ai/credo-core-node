defmodule CredoCoreNode.Adapters.BlockchainAdapter do
  alias CredoCoreNode.Blockchain.Block

  @callback last_block() :: %Block{}
  @callback last_processed_block(list()) :: %Block{}
  @callback list_processable_blocks(integer()) :: list()
end

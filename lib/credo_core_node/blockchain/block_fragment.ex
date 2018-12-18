defmodule CredoCoreNode.Blockchain.BlockFragment do
  use Mnesia.Schema, table_name: :block_fragments, fields: [:hash, :body]
end

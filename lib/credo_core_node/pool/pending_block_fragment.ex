defmodule CredoCoreNode.Pool.PendingBlockFragment do
  use Mnesia.Schema, table_name: :pending_block_fragments, fields: [:hash, :body]
end

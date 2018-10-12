defmodule CredoCoreNode.Validation.Vote do
  use Mnesia.Schema, table_name: :votes, fields: [:validator_address, :block_height, :block_hash]
end

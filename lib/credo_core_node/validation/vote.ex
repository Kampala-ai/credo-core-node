defmodule CredoCoreNode.Validation.Vote do
  use Mnesia.Schema, table_name: :votes, fields: [:validator_address, :block_height, :voting_round, :block_hash]
end

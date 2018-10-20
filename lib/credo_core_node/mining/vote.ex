defmodule CredoCoreNode.Mining.Vote do
  use Mnesia.Schema, table_name: :votes, fields: [:miner_address, :block_height, :voting_round, :block_hash]
end

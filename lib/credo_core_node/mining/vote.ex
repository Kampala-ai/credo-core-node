defmodule CredoCoreNode.Mining.Vote do
  use Mnesia.Schema, table_name: :votes, fields: [:miner_address, :block_number, :block_hash, :voting_round]
end

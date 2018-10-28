defmodule CredoCoreNode.Mining.Vote do
  use Mnesia.Schema,
    table_name: :votes,
    fields: [:miner_address, :block_number, :block_hash, :voting_round, :v, :r, :s]

  use RLP.Serializer

  @rlp_base_fields [
    miner_address: :string,
    block_number: :unsigned,
    block_hash: :string,
    voting_round: :unsigned
  ]
  @rlp_sig_fields [v: :unsigned, r: :string, s: :string]

  serialize(:default, @rlp_base_fields ++ @rlp_sig_fields)
  serialize(:unsigned, @rlp_base_fields)
end

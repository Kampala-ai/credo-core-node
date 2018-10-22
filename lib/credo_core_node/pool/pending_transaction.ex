defmodule CredoCoreNode.Pool.PendingTransaction do
  use Mnesia.Schema,
    table_name: :pending_transactions,
    fields: [:hash, :nonce, :to, :value, :fee, :data, :v, :r, :s]

  use RLP.Serializer

  @rlp_base_fields [
    nonce: :unsigned,
    to: :string,
    value: {:decimal, 18},
    fee: {:decimal, 18},
    data: :string
  ]
  @rlp_sig_fields [v: :unsigned, r: :string, s: :string]

  serialize(:default, @rlp_base_fields ++ @rlp_sig_fields)
  serialize(:unsigned, @rlp_base_fields)
end

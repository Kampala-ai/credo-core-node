defmodule CredoCoreNode.Blockchain.Block do
  # TODO:
  #   1. State and receipts are currently placeholders that are always empty; to be implemented
  #   2. Various additional data needed by smart contracts and light clients; to be designed
  use Mnesia.Schema,
    table_name: :blocks,
    fields: [:hash, :prev_hash, :number, :state_root, :receipt_root, :tx_root],
    virtual_fields: [:body]

  use RLP.Serializer

  @rlp_fields [
    prev_hash: :string,
    number: :unsigned,
    state_root: :string,
    receipt_root: :string,
    tx_root: :string
  ]

  serialize(@rlp_fields)
end

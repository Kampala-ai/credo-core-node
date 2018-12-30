defmodule CredoCoreNode.State.AccountState do
  defstruct([:address, :nonce, :balance, :storage_root, :code_hash])

  use RLP.Serializer

  serialize(nonce: :unsigned, balance: {:decimal, 18}, storage_root: :string, code_hash: :string)
end

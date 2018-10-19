defprotocol RLP.Hash do
  @doc "Returns RLP hash in binary encoding"
  def binary(record, options \\ [])

  @doc "Returns RLP hash in hex encoding"
  def hex(record, options \\ [])
end

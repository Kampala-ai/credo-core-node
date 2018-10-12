defmodule CredoCoreNode.Blockchain.Block do
  # TODO:
  #   1. State and receipts are currently placeholders that are always empty; to be implemented
  #   2. Body isn't supposed to be stored in Mnesia; to be moved to raw file system storage
  #   3. Various additional data needed by smart contracts and light clients; to be designed
  use Mnesia.Schema,
    table_name: :blocks,
    fields: [:hash, :prev_hash, :number, :state_root, :receipt_root, :tx_root, :body]

  alias CredoCoreNode.Blockchain.Block

  def hash(%Block{} = block, options \\ []) do
    hash =
      block
      |> ExRLP.encode(encoding: :hex)
      |> :libsecp256k1.sha256()

    if options[:encoding] == :hex, do: Base.encode16(hash), else: hash
  end

  def to_list(%Block{} = block, _options) do
    [block.prev_hash, block.number, block.state_root, block.receipt_root, block.tx_root]
  end

  defimpl ExRLP.Encode, for: __MODULE__ do
    alias ExRLP.Encode

    @spec encode(Block.t(), keyword()) :: binary()
    def encode(block, options \\ []) do
      block
      |> Block.to_list(options)
      |> Encode.encode(options)
    end
  end
end

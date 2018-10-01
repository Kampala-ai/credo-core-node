defmodule CredoCoreNode.Pool.PendingTransaction do
  use Mnesia.Schema,
    table_name: :pending_transactions,
    fields: [:hash, :nonce, :to, :value, :fee, :data, :v, :r, :s]

  alias CredoCoreNode.Pool.PendingTransaction

  def hash(%PendingTransaction{} = tx, options \\ []) do
    hash =
      tx
      |> ExRLP.encode(type: options[:type], encoding: :hex)
      |> :libsecp256k1.sha256()

    if options[:encoding] == :hex, do: Base.encode16(hash), else: hash
  end

  def to_list(%PendingTransaction{} = tx, options \\ []) do
    base_values = [tx.nonce, tx.to, tx.value, tx.fee, tx.data]
    sig_values = [tx.v, tx.r, tx.s]

    case options[:type] do
      :signed_rlp -> base_values ++ sig_values
      :unsigned_rlp -> base_values
      _ -> [tx.hash] ++ base_values ++ sig_values
    end
  end

  def from_list(list, options) do
    case options[:type] do
      :signed_rlp ->
        tx = from_list([nil] ++ list)

        Map.merge(tx, %{
          hash: hash(tx, type: :signed_rlp, encoding: :hex),
          nonce: :binary.decode_unsigned(tx.nonce),
          value: :binary.decode_unsigned(tx.value),
          fee: :binary.decode_unsigned(tx.fee),
          v: :binary.decode_unsigned(tx.v)
        })

      _ ->
        from_list(list)
    end
  end

  defimpl ExRLP.Encode, for: __MODULE__ do
    alias ExRLP.Encode

    @spec encode(PendingTransaction.t(), keyword()) :: binary()
    def encode(tx, options \\ []) do
      tx
      |> PendingTransaction.to_list(options)
      |> Encode.encode(options)
    end
  end
end

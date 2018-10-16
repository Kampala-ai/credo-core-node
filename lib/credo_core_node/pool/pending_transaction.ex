defmodule CredoCoreNode.Pool.PendingTransaction do
  use Mnesia.Schema,
    table_name: :pending_transactions,
    fields: [:hash, :nonce, :to, :value, :fee, :data, :v, :r, :s],
    rlp_support: true

  alias CredoCoreNode.Pool.PendingTransaction

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
end

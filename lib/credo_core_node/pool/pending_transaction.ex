defmodule CredoCoreNode.Pool.PendingTransaction do
  use Mnesia.Schema,
    table_name: :pending_transactions,
    fields: [:hash, :nonce, :to, :value, :fee, :data, :v, :r, :s]

  alias CredoCoreNode.Pool.PendingTransaction

  def unsigned_rlp(%PendingTransaction{} = tx) do
    ExRLP.encode(tx.nonce, encoding: :binary) <>
      ExRLP.encode(tx.to, encoding: :binary) <>
      ExRLP.encode(tx.value, encoding: :binary) <>
      ExRLP.encode(tx.fee, encoding: :binary) <> ExRLP.encode(tx.data, encoding: :binary)
  end

  def unsigned_rlp(tx), do: unsigned_rlp(struct(PendingTransaction, tx))

  def signed_rlp(unsigned_rlp, v, r, s) do
    unsigned_rlp <>
      ExRLP.encode(v, encoding: :binary) <>
      ExRLP.encode(r, encoding: :binary) <> ExRLP.encode(s, encoding: :binary)
  end

  def signed_rlp(%PendingTransaction{} = tx) do
    signed_rlp(unsigned_rlp(tx), tx.v, tx.r, tx.s)
  end

  def signed_rlp(tx), do: signed_rlp(struct(PendingTransaction, tx))
end

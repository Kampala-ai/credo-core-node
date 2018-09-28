defmodule CredoCoreNode.Pool do
  @moduledoc """
  The Pool context.
  """

  alias CredoCoreNode.Network
  alias CredoCoreNode.Pool.PendingTransaction
  alias Mnesia.Repo

  @doc """
  Returns the list of pending_transactions.
  """
  def list_pending_transactions() do
    Repo.list(PendingTransaction)
  end

  @doc """
  Gets a single pending_transaction.
  """
  def get_pending_transaction(hash) do
    Repo.get(PendingTransaction, hash)
  end

  @doc """
  Creates/updates a pending_transaction.
  """
  def write_pending_transaction(attrs) do
    Repo.write(PendingTransaction, attrs)
  end

  @doc """
  Deletes a pending_transaction.
  """
  def delete_pending_transaction(%PendingTransaction{} = pending_transaction) do
    Repo.delete(pending_transaction)
  end

  @doc """
  Generates a pending_transaction.
  """
  def generate_pending_transaction(private_key, attrs) do
    unsigned_rlp = PendingTransaction.unsigned_rlp(attrs)
    unsigned_hash = :libsecp256k1.sha256(unsigned_rlp)
    {:ok, sig, v} = :libsecp256k1.ecdsa_sign_compact(unsigned_hash, private_key, :default, <<>>)
    sig = Base.encode16(sig)
    r = String.slice(sig, 0, 64)
    s = String.slice(sig, 64, 64)
    signed_rlp = PendingTransaction.signed_rlp(unsigned_rlp, v, r, s)
    signed_hash = :libsecp256k1.sha256(signed_rlp)
    {:ok, struct(PendingTransaction, [hash: Base.encode16(signed_hash), v: v, r: r, s: s] ++ attrs)}
  end
end

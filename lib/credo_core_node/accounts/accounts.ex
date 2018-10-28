defmodule CredoCoreNode.Accounts do
  @moduledoc """
  The Accounts context.
  """

  alias CredoCoreNode.Accounts.Address
  alias CredoCoreNode.Pool.PendingTransaction

  alias Mnesia.Repo

  @doc """
  Calculates a public key for a given pending_transaction.
  """
  def calculate_public_key(%PendingTransaction{} = tx) do
    {:ok, sig} = Base.decode16(tx.r <> tx.s)

    # HACK: the version of libsecp256k1 we use adds `4` byte value to the beginning of public key
    {:ok, <<4>> <> public_key} =
      tx
      |> RLP.Hash.binary(type: :unsigned)
      |> :libsecp256k1.ecdsa_recover_compact(sig, :uncompressed, tx.v)

    {:ok, public_key}
  end

  @doc """
  Calculates a public key for a given private key byte sequence.
  """
  def calculate_public_key(private_key) when is_binary(private_key) do
    case :libsecp256k1.ec_pubkey_create(private_key, :uncompressed) do
      # HACK: the version of libsecp256k1 we use adds `4` byte value to the beginning of public key
      {:ok, <<4>> <> public_key} -> {:ok, public_key}
      result -> result
    end
  end

  @doc """
  Returns a payment address for a given public key.
  """
  def payment_address(public_key) do
    public_key
    |> :libsecp256k1.sha256()
    |> Base.encode16()
    |> String.slice(24, 40)
  end

  @doc """
  Generates a new address.
  """
  def generate_address(label \\ nil) do
    private_key =
      :crypto.strong_rand_bytes(32)

    {:ok, public_key} =
      calculate_public_key(private_key)

    write_address(%{
      address: payment_address(public_key),
      private_key: private_key,
      public_key: public_key,
      label: label
    })
  end

  @doc """
  Returns the list of addresss.
  """
  def list_addresss() do
    Repo.list(Address)
  end

  @doc """
  Gets a single address.
  """
  def get_address(address) do
    Repo.get(Address, address)
  end

  @doc """
  Creates/updates a address.
  """
  def write_address(attrs) do
    Repo.write(Address, attrs)
  end

  @doc """
  Deletes a address.
  """
  def delete_address(%Address{} = address) do
    Repo.delete(address)
  end
end

defmodule CredoCoreNode.Accounts do
  @moduledoc """
  The Accounts context.
  """

  alias CredoCoreNode.{Blockchain, Pool}
  alias CredoCoreNode.Accounts.Account
  alias CredoCoreNode.Pool.PendingTransaction
  alias CredoCoreNode.Mining.Vote

  alias Mnesia.Repo

  alias Decimal, as: D

  @doc """
  Calculates a public key for a given pending_transaction.
  """
  def calculate_public_key(%PendingTransaction{} = tx), do: calculate_public_key_from_signature(tx)
  def calculate_public_key(%Vote{} = vote), do: calculate_public_key_from_signature(vote)

  def calculate_public_key_from_signature(tx) do
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
  def payment_address(%Vote{} = vote) do
    vote
    |> calculate_public_key()
    |> payment_address()
  end

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

    write_account(%{
      address: payment_address(public_key),
      private_key: private_key,
      public_key: public_key,
      label: label
    })
  end

  @doc """
  Returns the list of accounts.
  """
  def list_accounts() do
    Repo.list(Account)
  end

  @doc """
  Gets a single account.
  """
  def get_account(account) do
    Repo.get(Account, account)
  end

  @doc """
  Creates/updates a account.
  """
  def write_account(attrs) do
    Repo.write(Account, attrs)
  end

  @doc """
  Deletes a account.
  """
  def delete_account(%Account{} = account) do
    Repo.delete(account)
  end

  def get_account_balance(address) do
    for block <- Blockchain.list_blocks() do # TODO: replace with more efficient implementation.
      for tx <- Blockchain.list_transactions(block) do
        from = Pool.get_transaction_from_address(tx)
        to = tx.to

        unless to == address && from == address do
          cond do
            address == to ->
              tx.value

            address == from ->
              D.minus(tx.value)

            true ->
              D.new(0)
          end
        end
      end
    end
    |> Enum.concat()
    |> Enum.reduce(fn x, acc -> D.add(x, acc) end)
  end
end

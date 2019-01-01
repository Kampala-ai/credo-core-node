defmodule CredoCoreNode.Accounts do
  @moduledoc """
  The Accounts context.
  """

  alias CredoCoreNode.{Blockchain, State}
  alias CredoCoreNode.Accounts.Account
  alias CredoCoreNode.Pool.PendingTransaction
  alias CredoCoreNode.Blockchain.Transaction
  alias CredoCoreNode.Mining.Vote

  alias Mnesia.Repo

  @behaviour CredoCoreNode.Adapters.AccountsAdapter

  @doc """
  Calculates a public key.
  """
  def calculate_public_key(%PendingTransaction{} = tx),
    do: calculate_public_key_from_signature(tx)

  def calculate_public_key(%Transaction{} = tx), do: calculate_public_key_from_signature(tx)
  def calculate_public_key(%Vote{} = vote), do: calculate_public_key_from_signature(vote)

  def calculate_public_key(private_key) when is_binary(private_key) do
    case :libsecp256k1.ec_pubkey_create(private_key, :uncompressed) do
      # HACK: the version of libsecp256k1 we use adds `4` byte value to the beginning of public key
      {:ok, <<4>> <> public_key} ->
        {:ok, public_key}

      result ->
        result
    end
  end

  defp calculate_public_key_from_signature(tx) do
    {:ok, sig} = Base.decode16(tx.r <> tx.s)

    # HACK: the version of libsecp256k1 we use adds `4` byte value to the beginning of public key
    {:ok, <<4>> <> public_key} =
      tx
      |> RLP.Hash.binary(type: :unsigned)
      |> :libsecp256k1.ecdsa_recover_compact(sig, :uncompressed, tx.v)

    {:ok, public_key}
  end

  @doc """
  Returns a payment address for a given public key.
  """
  def payment_address(%Vote{} = vote) do
    vote
    |> calculate_public_key()
    |> elem(1)
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
    private_key = :crypto.strong_rand_bytes(32)

    {:ok, public_key} = calculate_public_key(private_key)

    write_account(%{
      address: payment_address(public_key),
      private_key: private_key,
      public_key: public_key,
      label: label
    })
  end

  def save_account(base16_private_key, label \\ nil) do
    {:ok, private_key} = Base.decode16(base16_private_key)

    {:ok, public_key} = calculate_public_key(private_key)

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

  def get_account_state(address, last_block) do
    last_block_number =
      case last_block do
        %{number: number} -> number
        _ -> Blockchain.last_confirmed_block_number()
      end

    state_trie =
      last_block_number
      |> State.calculate_world_state!()
      |> State.state_trie()

    account_state = State.get_account_state(state_trie, address)

    Exleveldb.close(elem(state_trie.db, 1))

    account_state
  end

  def get_account_balance(address, last_block \\ nil) do
    account_state = get_account_state(address, last_block)

    account_state.balance
  end

  def get_account_nonce(address, last_block \\ nil) do
    account_state = get_account_state(address, last_block)

    account_state.nonce
  end
end

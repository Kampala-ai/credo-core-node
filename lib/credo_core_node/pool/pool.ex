defmodule CredoCoreNode.Pool do
  @moduledoc """
  The Pool context.
  """

  alias CredoCoreNode.{Blockchain, Network}
  alias CredoCoreNode.Pool.{PendingBlock, PendingTransaction}
  alias Mnesia.Repo
  alias MerklePatriciaTree.Trie

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
  Gets the sum of pending transaction fees.
  """
  def sum_pending_transaction_fees(txs) do
    for %{fee: fee, id: _} <- txs, do: fee
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
    tx = struct(PendingTransaction, attrs)

    {:ok, sig, v} =
      tx
      |> RLP.Hash.binary(type: :unsigned)
      |> :libsecp256k1.ecdsa_sign_compact(private_key, :default, <<>>)

    sig = Base.encode16(sig)
    tx = Map.merge(tx, %{v: v, r: String.slice(sig, 0, 64), s: String.slice(sig, 64, 64)})

    {:ok, %{tx | hash: RLP.Hash.hex(tx)}}
  end

  @doc """
  Propagates a pending_transaction.
  """
  def propagate_pending_transaction(tx) do
    # TODO: temporary REST implementation, to be replaced with channels-based one later
    headers = Network.node_request_headers()
    {:ok, body} = Poison.encode(%{hash: tx.hash, body: ExRLP.encode(tx, encoding: :hex)})

    Network.list_connections()
    |> Enum.filter(& &1.is_active)
    |> Enum.map(&"#{Network.request_url(&1.ip)}/node_api/v1/temp/pending_transactions")
    |> Enum.each(&:hackney.request(:post, &1, headers, body, [:with_body, pool: false]))

    {:ok, tx}
  end

  @doc """
  Gets a batch of a pending_transaction.

  To be called when constructing a block.
  """
  def get_batch_of_pending_transactions do
    list_pending_transactions()
    |> Enum.sort(&(&1.fee > &2.fee))
    |> Enum.take(200)
  end

  @doc """
  Returns the list of pending_blocks.
  """
  def list_pending_blocks() do
    Repo.list(PendingBlock)
  end

  @doc """
  Returns the list of pending_blocks for a given block number.
  """
  def list_pending_blocks(number) do
    list_pending_blocks()
    |> Enum.filter(&(&1.number == number))
  end

  @doc """
  Gets a single pending_block.
  """
  def get_pending_block(hash) do
    Repo.get(PendingBlock, hash)
  end

  def get_block_by_number(number) do
    list_pending_blocks(number)
    |> List.first()
  end

  @doc """
  Creates/updates a pending_block.
  """
  def write_pending_block(%PendingBlock{hash: hash, tx_trie: tx_trie} = pending_block)
      when not is_nil(hash) and not is_nil(tx_trie) do
    tx_trie
    |> Map.put(:db, MerklePatriciaTree.DB.LevelDB.init("./leveldb/pending_blocks/#{hash}"))
    |> Trie.store()

    pending_block
    |> Map.drop([:hash, :trie])
    |> write_pending_block()
  end

  @doc """
  Creates/updates a pending_block.
  """
  def write_pending_block(attrs) do
    Repo.write(PendingBlock, attrs)
  end

  @doc """
  Deletes a pending_block.
  """
  def delete_pending_block(%PendingBlock{} = pending_block) do
    Repo.delete(pending_block)
  end

  @doc """
  Generates a pending_block.
  """
  def generate_pending_block(pending_transactions) do
    last_block =
      Blockchain.list_blocks()
      |> Enum.sort(&(&1.number > &2.number))
      |> List.first()

    {number, prev_hash} =
      if last_block, do: {last_block.number + 1, last_block.hash}, else: {0, ""}

    # Temporary in-memory storage
    tx_trie =
      MerklePatriciaTree.DB.ETS.random_ets_db()
      |> Trie.new()
      |> put_transactions_to_trie(pending_transactions)

    tx_root = Base.encode16(tx_trie.root_hash)

    pending_block = %PendingBlock{
      prev_hash: prev_hash,
      number: number,
      state_root: "",
      receipt_root: "",
      tx_root: tx_root,
      body: nil
    }

    {:ok, %PendingBlock{pending_block | hash: RLP.Hash.hex(pending_block), tx_trie: tx_trie}}
  end

  def propagate_block(block, recipients \\ :miners) do
  end

  # TODO: converting lists of items of a specific type to a trie is a patterned task,
  #   to be moved to a module and/or a protocol
  defp put_transactions_to_trie(trie, pending_transactions) do
    Enum.reduce(
      pending_transactions,
      trie,
      &Trie.update(&2, elem(Base.decode16(&1.hash), 1), ExRLP.encode(&1))
    )
  end
end

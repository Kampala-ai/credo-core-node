defmodule CredoCoreNode.Pool do
  @moduledoc """
  The Pool context.
  """

  alias CredoCoreNode.{Accounts, Blockchain, Network}
  alias CredoCoreNode.Pool.{PendingBlock, PendingBlockFragment, PendingTransaction}
  alias CredoCoreNode.Blockchain.Block
  alias CredoCoreNodeWeb.Endpoint
  alias MerklePatriciaTree.Trie

  alias Decimal, as: D

  @doc """
  Returns the list of pending_transactions.
  """
  def list_pending_transactions() do
    Mnesia.Repo.list(PendingTransaction)
  end

  def list_pending_transactions(%PendingBlock{} = pending_block) do
    case pending_block_tx_trie(pending_block) do
      nil ->
        []

      tx_trie ->
        txs = MPT.Repo.list(tx_trie, PendingTransaction)
        Exleveldb.close(elem(tx_trie.db, 1))
        txs
    end
  end

  @doc """
  Gets a single pending_transaction.
  """
  def get_pending_transaction(hash) do
    Mnesia.Repo.get(PendingTransaction, hash)
  end

  @doc """
  Gets the sum of pending transaction fees.
  """
  def sum_pending_transaction_fees(txs) do
    fees = for %{fee: fee} <- txs, do: D.new(fee)
    Enum.reduce(fees, fn x, acc -> D.add(x, acc) end)
  end

  def sum_pending_transaction_values(%PendingBlock{} = block) do
    block
    |> list_pending_transactions()
    |> sum_pending_transaction_values()
  end

  def sum_pending_transaction_values(txs) do
    fees = for %{value: value} <- txs, do: D.new(value)
    Enum.reduce(fees, fn x, acc -> D.add(x, acc) end)
  end

  @doc """
  Creates/updates a pending_transaction.
  """
  def write_pending_transaction(attrs) do
    Mnesia.Repo.write(PendingTransaction, attrs)
  end

  @doc """
  Deletes a pending_transaction.
  """
  def delete_pending_transaction(%PendingTransaction{} = pending_transaction) do
    Mnesia.Repo.delete(pending_transaction)
  end

  @doc """
  Generates a pending_transaction.
  """
  def generate_pending_transaction(private_key, attrs) do
    tx = struct(PendingTransaction, attrs)

    to =
      case tx.to do
        "0x" <> to -> String.upcase(to)
        to -> String.upcase(to)
      end

    value = D.new(tx.value)
    fee = D.new(tx.fee)
    data = tx.data || ""
    tx = sign_message(private_key, %{tx | to: to, data: data, value: value, fee: fee})

    {:ok, %{tx | hash: RLP.Hash.hex(tx)}}
  end

  def sign_message(private_key, message) do
    {:ok, sig, v} =
      message
      |> RLP.Hash.binary(type: :unsigned)
      |> :libsecp256k1.ecdsa_sign_compact(private_key, :default, <<>>)

    sig = Base.encode16(sig)
    Map.merge(message, %{v: v, r: String.slice(sig, 0, 64), s: String.slice(sig, 64, 64)})
  end

  @doc """
  Propagates a pending_transaction.
  """
  def propagate_pending_transaction(tx, options \\ []) do
    Network.propagate_record(tx, options)

    {:ok, tx}
  end

  @doc """
  Gets a batch of a pending_transaction.

  To be called when constructing a block.
  """
  def get_batch_of_valid_pending_transactions() do
    list_pending_transactions()
    |> Enum.sort(&(&1.fee > &2.fee))
    |> Enum.filter(&is_tx_valid?(&1))
    |> Enum.take(2000)
  end

  @doc """
  Returns the list of pending_block_fragments.
  """
  def list_pending_block_fragments() do
    Mnesia.Repo.list(PendingBlockFragment)
  end

  @doc """
  Gets a single pending_block_fragment.
  """
  def get_pending_block_fragment(hash) do
    Mnesia.Repo.get(PendingBlockFragment, hash)
  end

  @doc """
  Creates/updates a pending_block_fragment.
  """
  def write_pending_block_fragment(attrs) do
    Mnesia.Repo.write(PendingBlockFragment, attrs)
  end

  @doc """
  Deletes a pending_block_fragment.
  """
  def delete_pending_block_fragment(%PendingBlockFragment{} = pending_block_fragment) do
    Mnesia.Repo.delete(pending_block_fragment)
  end

  @doc """
  Returns the list of pending_blocks.
  """
  def list_pending_blocks() do
    Mnesia.Repo.list(PendingBlock)
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
    Mnesia.Repo.get(PendingBlock, hash)
  end

  def get_block_by_number(number) do
    list_pending_blocks(number)
    |> List.first()
  end

  def load_pending_block_body(nil), do: nil

  def load_pending_block_body(%PendingBlock{} = pending_block) do
    case pending_block_tx_trie(pending_block) do
      nil ->
        pending_block

      tx_trie ->
        body =
          tx_trie
          |> MPT.Repo.list(PendingTransaction)
          |> ExRLP.encode()

        Exleveldb.close(elem(tx_trie.db, 1))

        %{pending_block | body: body}
    end
  end

  @doc """
  Creates/updates a pending_block.
  """
  def write_pending_block(%PendingBlock{hash: hash, body: body} = pending_block)
      when not is_nil(hash) and not is_nil(body) do
    pending_transactions =
      body
      |> ExRLP.decode()
      |> Enum.map(&PendingTransaction.from_list(&1, type: :rlp_default))

    {:ok, tx_trie, _pending_transactions} =
      "#{File.cwd!()}/leveldb/pending_blocks/#{hash}"
      |> MerklePatriciaTree.DB.LevelDB.init()
      |> Trie.new()
      |> MPT.Repo.write_list(PendingTransaction, pending_transactions)

    tx_root = Base.encode16(tx_trie.root_hash)
    Exleveldb.close(elem(tx_trie.db, 1))

    pending_block
    |> Map.drop([:tx_trie, :body])
    |> Map.put(:tx_root, tx_root)
    |> write_pending_block()
  end

  @doc """
  Creates/updates a pending_block.
  """
  def write_pending_block(attrs) do
    Mnesia.Repo.write(PendingBlock, attrs)
  end

  @doc """
  Deletes a pending_block.
  """
  def delete_pending_block(%PendingBlock{} = pending_block) do
    Mnesia.Repo.delete(pending_block)
  end

  @doc """
  Generates a pending_block.
  """
  def generate_pending_block(pending_transactions) when pending_transactions == [],
    do: {:error, :no_txs}

  def generate_pending_block(pending_transactions) do
    last_block =
      Blockchain.list_blocks()
      |> Enum.sort(&(&1.number > &2.number))
      |> List.first()

    {number, prev_hash} =
      if last_block, do: {last_block.number + 1, last_block.hash}, else: {0, ""}

    # Temporary in-memory storage, need this only to properly calculate tx_root and hash
    {:ok, tx_trie, _pending_transactions} =
      MerklePatriciaTree.DB.ETS.random_ets_db()
      |> Trie.new()
      |> MPT.Repo.write_list(PendingTransaction, pending_transactions)

    tx_root = Base.encode16(tx_trie.root_hash)

    pending_block = %PendingBlock{
      prev_hash: prev_hash,
      number: number,
      state_root: "",
      receipt_root: "",
      tx_root: tx_root,
      body: ExRLP.encode(pending_transactions)
    }

    {:ok, %PendingBlock{pending_block | hash: RLP.Hash.hex(pending_block)}}
  end

  def fetch_pending_block_body(pending_block, ip),
    do: fetch_pending_block_body(pending_block, ip, Network.connection_type(ip))

  def fetch_pending_block_body(pending_block, ip, :outgoing) do
    url = "#{Network.api_url(ip)}/pending_block_bodies/#{pending_block.hash}"
    headers = Network.node_request_headers(:rlp)

    case :hackney.request(:get, url, headers, "", [:with_body, pool: false]) do
      {:ok, 200, _headers, body} ->
        write_pending_block(%{pending_block | body: body})
        propagate_pending_block(pending_block)
      _ -> nil
    end
  end

  def fetch_pending_block_body(pending_block, ip, :incoming) do
    Endpoint.broadcast!(
      "node_socket:#{Network.get_connection(ip).session_id}",
      "pending_blocks:body_request",
      %{hash: pending_block.hash}
    )
  end

  def propagate_pending_block(block, options \\ []) do
    Network.propagate_record(block, options ++ [recipients: :miners])

    {:ok, block}
  end

  def get_transaction_from_address(tx) do
    tx
    |> Accounts.calculate_public_key()
    |> elem(1)
    |> Accounts.payment_address()
  end

  def is_tx_unmined?(tx), do: is_tx_unmined?(tx, %Block{prev_hash: Blockchain.last_block().hash})

  def is_tx_unmined?(tx, block) do
    for block <- Blockchain.list_preceding_blocks(block) do
      for mined_tx <- Blockchain.list_transactions(block) do
        tx.hash != mined_tx.hash
      end
    end
    |> Enum.concat()
    |> Enum.reduce(true, &(&1 && &2))
  end

  def is_tx_from_balance_sufficient?(tx) do
    tx
    |> get_transaction_from_address()
    |> Accounts.get_account_balance()
    |> D.cmp(D.new(tx.value)) == :gt
  end

  def is_tx_valid?(tx) do
    is_tx_from_balance_sufficient?(tx) && is_tx_unmined?(tx)
  end

  # HACK: temporary disabled balance check to be able to generate pending transactions on testnet
  def is_tx_invalid?(tx) do
    # !is_tx_from_balance_sufficient?(tx)
    false
  end

  def pending_block_body_fetched?(%PendingBlock{tx_root: nil}), do: false
  def pending_block_body_fetched?(%PendingBlock{hash: nil}), do: false

  def pending_block_body_fetched?(%PendingBlock{hash: hash}),
    do: File.exists?("#{File.cwd!()}/leveldb/pending_blocks/#{hash}")

  defp pending_block_tx_trie(%PendingBlock{tx_root: nil}), do: nil
  defp pending_block_tx_trie(%PendingBlock{hash: nil}), do: nil

  defp pending_block_tx_trie(%PendingBlock{tx_root: tx_root, hash: hash}) do
    path = "#{File.cwd!()}/leveldb/pending_blocks/#{hash}"
    {:ok, tx_root} = Base.decode16(tx_root)

    if File.exists?(path) do
      path
      |> MerklePatriciaTree.DB.LevelDB.init()
      |> Trie.new(tx_root)
    end
  end
end

defmodule CredoCoreNode.Blockchain do
  @moduledoc """
  The Blockchain context.
  """

  alias CredoCoreNode.Blockchain.{Block, Transaction}
  alias CredoCoreNode.Pool
  alias CredoCoreNode.Network
  alias MerklePatriciaTree.Trie

  alias Decimal, as: D

  @finalization_threshold 12

  def coinbase_tx_type, do: "coinbase"
  def security_deposit_tx_type, do: "security_deposit"
  def slash_tx_type, do: "slash"
  def update_miner_ip_tx_type, do: "update_miner_ip"
  def finalization_threshold, do: @finalization_threshold

  def last_finalized_block_number, do: max(last_confirmed_block_number() - finalization_threshold(), 0)

  def last_confirmed_block_number() do
    case last_block() do
      %{number: number} ->
        number

      nil ->
        0
    end
  end

  @doc """
  Returns the list of transactions.
  """
  def list_transactions() do
    Mnesia.Repo.list(Transaction)
  end

  @doc """
  Returns the list of transactions.
  """
  def list_transactions(%Block{} = block) do
    case block_tx_trie(block) do
      nil -> []
      tx_trie ->
        txs = MPT.Repo.list(tx_trie, Transaction)
        Exleveldb.close(elem(tx_trie.db, 1))
        txs
    end
  end

  @doc """
  Gets a single transaction.
  """
  def get_transaction(hash) do
    Mnesia.Repo.get(Transaction, hash)
  end

  @doc """
  Creates/updates a transaction.
  """
  def write_transaction(attrs) do
    Mnesia.Repo.write(Transaction, attrs)
  end

  @doc """
  Deletes a transaction.
  """
  def delete_transaction(%Transaction{} = transaction) do
    Mnesia.Repo.delete(transaction)
  end

  @doc """
  Returns the list of blocks.
  """
  def list_blocks() do
    Mnesia.Repo.list(Block)
  end

  def list_preceding_blocks(block) do
    case get_block(block.prev_hash) do
      nil -> []
      block ->
        [block] ++ list_preceding_blocks(block)
    end
  end

  def list_processable_blocks(last_processed_block_number) do
    Enum.filter(list_blocks(),
      &(&1.number > last_processed_block_number &&
      &1.number < last_finalized_block_number()))
  end

  def last_processed_block(processable_blocks) do
    processable_blocks
    |> Enum.sort(&(&1.number > &2.number))
    |> List.first()
  end

  @doc """
  Returns the last confirmed blocks.
  """
  def last_block() do
    list_blocks()
    |> Enum.sort(&(&1.number > &2.number))
    |> List.first() || load_genesis_block()
  end

  def load_genesis_block() do
    if block = get_block_by_number(0) do
      block
    else
      genesis_block_attrs =
        [struct(CredoCoreNode.Pool.PendingTransaction, [
          data: "",
          fee: D.new(1.1),
          hash: "680E3A773979575FC3E8B8FE2A42D864F881FD29C018A8F129629EC7084EB7DB",
          nonce: 0,
          r: "B7A3424EB20CB5A75BFEC0B2BC7A9EF0CC649B7EFD784442A11B612492349686",
          s: "4355A76B08672ADDFD0BED4F42DB5A6EFBE7AC582FCAE2E6D26AF3921A009C79",
          to: "F7DA6E2803E37C10D591C08EBFE2F8A018352955",
          v: 1,
          value: D.new(1374719257.2286)
        ]),
        struct(CredoCoreNode.Pool.PendingTransaction, [
          data: "{\"tx_type\" : \"security_deposit\", \"node_ip\" : \"10.0.1.9\", \"timelock\": \"\"}",
          fee: D.new(1.0),
          hash: "A588D170F64FC3ADAF805670DA67C152FA906B8BB855AAA9B2041ED8E2747FF1",
          nonce: 0,
          r: "389576343235F0311A7FA5DD8BCE9C6E529698B66AB146427403C4B6863DC801",
          s: "46A623CC9B3FAFB41F35A698EE4C7ED73C76FA01D8E12209A76046C0B120D0E9",
          to: "A9A2B9A1EBDDE9EEB5EF733E47FC137D7EB95340",
          v: 0,
          value: D.new(10000.0)
        ])]
        |> CredoCoreNode.Pool.generate_pending_block()
        |> elem(1)
        |> Map.to_list()

      block =
        struct(CredoCoreNode.Blockchain.Block, genesis_block_attrs)
        |> CredoCoreNode.Blockchain.write_block()
        |> elem(1)

      CredoCoreNode.Mining.Deposit.maybe_recognize_deposits(block)

      block
    end
  end

  @doc """
  Gets a single block.
  """
  def get_block(hash) do
    Mnesia.Repo.get(Block, hash)
  end

  def get_block_by_number(number) do
    list_blocks()
    |> Enum.filter(&(&1.number == number))
    |> List.first()
  end

  def load_block_body(nil), do: nil

  def load_block_body(%Block{} = block) do
    case block_tx_trie(block) do
      nil -> block
      tx_trie ->
        body =
          tx_trie
          |> MPT.Repo.list(Transaction)
          |> ExRLP.encode()

        Exleveldb.close(elem(tx_trie.db, 1))

        %{block | body: body}
    end
  end

  @doc """
  Creates/updates a block.
  """
  def write_block(%Block{hash: hash, body: body} = block)
      when not is_nil(hash) and not is_nil(body) do
    transactions =
      body
      |> ExRLP.decode()
      |> Enum.map(&Transaction.from_list(&1, type: :rlp_default))

    {:ok, tx_trie, _transactions} =
      "#{File.cwd!}/leveldb/blocks/#{hash}"
      |> MerklePatriciaTree.DB.LevelDB.init()
      |> Trie.new()
      |> MPT.Repo.write_list(Transaction, transactions)

    tx_root = Base.encode16(tx_trie.root_hash)
    Exleveldb.close(elem(tx_trie.db, 1))

    block
    |> Map.drop([:body])
    |> Map.put(:tx_root, tx_root)
    |> write_block()
  end

  @doc """
  Creates/updates a block.
  """
  def write_block(attrs) do
    Mnesia.Repo.write(Block, attrs)
  end

  @doc """
  Marks a block as invalid.
  """
  def mark_block_as_invalid(pending_block) do
    Pool.delete_pending_block(pending_block)
  end

  @doc """
  Deletes a block.
  """
  def delete_block(%Block{} = block) do
    Mnesia.Repo.delete(block)
  end

  def fetch_block_body(block) do
    Network.list_connections()
    |> Enum.filter(& &1.is_active)
    |> Enum.each(fn connection ->
      unless block_body_fetched?(block), do: fetch_block_body(block, connection.ip)
    end)

    if block_body_fetched?(block) do
      {:ok, block}
    else
      {:error, :unknown}
    end
  end

  def fetch_block_body(block, ip) do
    url = "#{Network.api_url(ip)}/block_bodies/#{block.hash}"
    headers = Network.node_request_headers(:rlp)

    case :hackney.request(:get, url, headers, "", [:with_body, pool: false]) do
      {:ok, 200, _headers, body} -> write_block(%{block | body: body})
      {:ok, 204, _headers, _body} -> {:error, :no_content}
      {:ok, 404, _headers, _body} -> {:error, :not_found}
      _ -> {:error, :unknown}
    end
  end

  def propagate_block(block, options \\ []) do
    Network.propagate_record(block, options)

    {:ok, block}
  end

  def block_body_fetched?(%Block{tx_root: nil}), do: false
  def block_body_fetched?(%Block{hash: nil}), do: false

  def block_body_fetched?(%Block{hash: hash}),
    do: File.exists?("#{File.cwd!}/leveldb/blocks/#{hash}")

  defp block_tx_trie(%Block{tx_root: nil}), do: nil
  defp block_tx_trie(%Block{hash: nil}), do: nil

  defp block_tx_trie(%Block{tx_root: tx_root, hash: hash}) do
    path = "#{File.cwd!}/leveldb/blocks/#{hash}"
    {:ok, tx_root} = Base.decode16(tx_root)

    if File.exists?(path) do
      path
      |> MerklePatriciaTree.DB.LevelDB.init()
      |> Trie.new(tx_root)
    end
  end
end

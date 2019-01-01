defmodule CredoCoreNode.Blockchain do
  @moduledoc """
  The Blockchain context.
  """

  alias CredoCoreNode.{Pool, Network, State}
  alias CredoCoreNode.Blockchain.{Block, BlockFragment, Transaction}
  alias CredoCoreNode.Mining.Coinbase
  alias CredoCoreNode.Pool.PendingBlock
  alias CredoCoreNodeWeb.Endpoint
  alias MerklePatriciaTree.Trie

  alias Decimal, as: D

  @behaviour CredoCoreNode.Adapters.BlockchainAdapter

  @irreversibility_threshold 12

  def coinbase_tx_type, do: "coinbase"
  def security_deposit_tx_type, do: "security_deposit"
  def slash_tx_type, do: "slash"
  def update_miner_ip_tx_type, do: "update_miner_ip"
  def irreversibility_threshold, do: @irreversibility_threshold

  def last_irreversible_block_number,
    do: max(last_confirmed_block_number() - irreversibility_threshold(), 0)

  def last_confirmed_block_number() do
    case last_block() do
      %{number: number} ->
        number

      nil ->
        -1
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
  def list_transactions(%PendingBlock{} = block), do: Pool.list_pending_transactions(block)

  def list_transactions(%Block{} = block) do
    case block_tx_trie(block) do
      nil ->
        []

      tx_trie ->
        txs = MPT.Repo.list(tx_trie, Transaction)
        Exleveldb.close(elem(tx_trie.db, 1))
        txs
    end
  end

  def list_non_coinbase_transactions(block) do
    block
    |> list_transactions()
    |> Enum.reject(&Coinbase.is_coinbase_tx?(&1))
  end

  def sum_transaction_values(%Block{} = block) do
    block
    |> list_transactions()
    |> sum_transaction_values()
  end

  def sum_transaction_values(txs) do
    fees = for %{value: value} <- txs, do: D.new(value)
    Enum.reduce(fees, fn x, acc -> D.add(x, acc) end)
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
  Returns the list of block_fragments.
  """
  def list_block_fragments() do
    Mnesia.Repo.list(BlockFragment)
  end

  @doc """
  Gets a single block_fragment.
  """
  def get_block_fragment(hash) do
    Mnesia.Repo.get(BlockFragment, hash)
  end

  @doc """
  Creates/updates a block_fragment.
  """
  def write_block_fragment(attrs) do
    Mnesia.Repo.write(BlockFragment, attrs)
  end

  @doc """
  Deletes a block_fragment.
  """
  def delete_block_fragment(%BlockFragment{} = block_fragment) do
    Mnesia.Repo.delete(block_fragment)
  end

  @doc """
  Returns the list of blocks.
  """
  def list_blocks() do
    Mnesia.Repo.list(Block)
  end

  def list_preceding_blocks(block) do
    case get_block(block.prev_hash) do
      nil ->
        []

      block ->
        [block] ++ list_preceding_blocks(block)
    end
  end

  def list_processable_blocks(last_processed_block_number) do
    Enum.filter(
      list_blocks(),
      &(&1.number > last_processed_block_number && &1.number < last_irreversible_block_number())
    )
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
    |> List.first()
  end

  def load_genesis_block() do
    if block = get_block_by_number(0) do
      block
    else
      block =
        %Block{
          body:
            <<249, 1, 216, 248, 198, 128, 168, 70, 55, 68, 65, 54, 69, 50, 56, 48, 51, 69, 51, 55,
              67, 49, 48, 68, 53, 57, 49, 67, 48, 56, 69, 66, 70, 69, 50, 70, 56, 65, 48, 49, 56,
              51, 53, 50, 57, 53, 53, 140, 4, 113, 36, 32, 67, 34, 130, 250, 144, 107, 128, 0,
              136, 15, 67, 252, 44, 4, 238, 0, 0, 128, 1, 184, 64, 66, 55, 65, 51, 52, 50, 52, 69,
              66, 50, 48, 67, 66, 53, 65, 55, 53, 66, 70, 69, 67, 48, 66, 50, 66, 67, 55, 65, 57,
              69, 70, 48, 67, 67, 54, 52, 57, 66, 55, 69, 70, 68, 55, 56, 52, 52, 52, 50, 65, 49,
              49, 66, 54, 49, 50, 52, 57, 50, 51, 52, 57, 54, 56, 54, 184, 64, 52, 51, 53, 53, 65,
              55, 54, 66, 48, 56, 54, 55, 50, 65, 68, 68, 70, 68, 48, 66, 69, 68, 52, 70, 52, 50,
              68, 66, 53, 65, 54, 69, 70, 66, 69, 55, 65, 67, 53, 56, 50, 70, 67, 65, 69, 50, 69,
              54, 68, 50, 54, 65, 70, 51, 57, 50, 49, 65, 48, 48, 57, 67, 55, 57, 249, 1, 13, 128,
              168, 65, 57, 65, 50, 66, 57, 65, 49, 69, 66, 68, 68, 69, 57, 69, 69, 66, 53, 69, 70,
              55, 51, 51, 69, 52, 55, 70, 67, 49, 51, 55, 68, 55, 69, 66, 57, 53, 51, 52, 48, 138,
              2, 30, 25, 224, 201, 186, 178, 64, 0, 0, 136, 13, 224, 182, 179, 167, 100, 0, 0,
              184, 72, 123, 34, 116, 120, 95, 116, 121, 112, 101, 34, 32, 58, 32, 34, 115, 101,
              99, 117, 114, 105, 116, 121, 95, 100, 101, 112, 111, 115, 105, 116, 34, 44, 32, 34,
              110, 111, 100, 101, 95, 105, 112, 34, 32, 58, 32, 34, 49, 48, 46, 48, 46, 49, 46,
              57, 34, 44, 32, 34, 116, 105, 109, 101, 108, 111, 99, 107, 34, 58, 32, 34, 34, 125,
              128, 184, 64, 51, 56, 57, 53, 55, 54, 51, 52, 51, 50, 51, 53, 70, 48, 51, 49, 49,
              65, 55, 70, 65, 53, 68, 68, 56, 66, 67, 69, 57, 67, 54, 69, 53, 50, 57, 54, 57, 56,
              66, 54, 54, 65, 66, 49, 52, 54, 52, 50, 55, 52, 48, 51, 67, 52, 66, 54, 56, 54, 51,
              68, 67, 56, 48, 49, 184, 64, 52, 54, 65, 54, 50, 51, 67, 67, 57, 66, 51, 70, 65, 70,
              66, 52, 49, 70, 51, 53, 65, 54, 57, 56, 69, 69, 52, 67, 55, 69, 68, 55, 51, 67, 55,
              54, 70, 65, 48, 49, 68, 56, 69, 49, 50, 50, 48, 57, 65, 55, 54, 48, 52, 54, 67, 48,
              66, 49, 50, 48, 68, 48, 69, 57>>,
          hash: "C34C9F7B1C2657DB01B825F805AC1363804DFA7FA884BD8A9D085C1FD7BD137A",
          number: 0,
          prev_hash: "",
          receipt_root: "",
          state_root: "",
          tx_root: "55A0D0EC08B7490480D2F2080B4B318E2223D2530845E811A2F265D4E8AD9E6B"
        }
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
      nil ->
        block

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
  def write_block(%Block{hash: hash, body: body, state_root: state_root} = block)
      when not is_nil(hash) and not is_nil(body) do
    transactions =
      body
      |> ExRLP.decode()
      |> Enum.map(&Transaction.from_list(&1, type: :rlp_default))

    {:ok, tx_trie, _transactions} =
      "#{File.cwd!()}/leveldb/blocks/#{hash}"
      |> MerklePatriciaTree.DB.LevelDB.init()
      |> Trie.new()
      |> MPT.Repo.write_list(Transaction, transactions)

    tx_root = Base.encode16(tx_trie.root_hash)
    Exleveldb.close(elem(tx_trie.db, 1))

    case State.calculate_world_state(transactions) do
      {:ok, ^state_root} ->
        block
        |> Map.drop([:body])
        |> Map.put(:tx_root, tx_root)
        |> write_block()

      # TODO: backwards-compatibility block. On the current testnet version, early blocks have
      #   empty `state_root` value. To be removed after moving to mainnet.
      {:ok, _state_root} when state_root == "" ->
        block
        |> Map.drop([:body])
        |> Map.put(:tx_root, tx_root)
        |> write_block()

      _ ->
        {:error, :invalid_state}
    end
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
  def mark_block_as_invalid(%Block{}), do: nil

  def mark_block_as_invalid(pending_block) do
    # Pool.delete_pending_block(pending_block)
  end

  @doc """
  Deletes a block.
  """
  def delete_block(%Block{} = block) do
    Mnesia.Repo.delete(block)
  end

  def fetch_block_body(block, ip), do: fetch_block_body(block, ip, Network.connection_type(ip))

  def fetch_block_body(block, ip, :outgoing) do
    url = "#{Network.api_url(ip)}/block_bodies/#{block.hash}"
    headers = Network.node_request_headers(:rlp)

    case :hackney.request(:get, url, headers, "", [:with_body, pool: false]) do
      {:ok, 200, _headers, body} ->
        write_block(%{block | body: body})
        propagate_block(block)

      _ ->
        nil
    end
  end

  def fetch_block_body(block, ip, :incoming) do
    Endpoint.broadcast!(
      "node_socket:#{Network.get_connection(ip).session_id}",
      "blocks:body_request",
      %{hash: block.hash}
    )
  end

  def propagate_block(block, options \\ []) do
    Network.propagate_record(block, options)

    {:ok, block}
  end

  def block_body_fetched?(%Block{tx_root: nil}), do: false
  def block_body_fetched?(%Block{hash: nil}), do: false

  def block_body_fetched?(%Block{hash: hash}), do: MPT.RepoManager.trie_exists?("blocks", hash)

  defp block_tx_trie(%Block{tx_root: nil}), do: nil
  defp block_tx_trie(%Block{hash: nil}), do: nil

  defp block_tx_trie(%Block{tx_root: tx_root, hash: hash}) do
    case MPT.RepoManager.trie("blocks", hash, tx_root) do
      {:error, _reason} -> nil
      trie -> trie
    end
  end
end

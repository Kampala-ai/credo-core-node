defmodule CredoCoreNode.State do
  @moduledoc """
  The State context.
  """

  alias CredoCoreNode.State.{AccountState, InvalidRootError, MissingBlockBodyError, DbAccessError}
  alias CredoCoreNode.{Blockchain, Pool}
  alias MerklePatriciaTree.Trie
  alias Decimal, as: D

  @doc """
  Gets a single account_state.
  """
  def get_account_state(trie, address) do
    case MPT.Repo.get(trie, AccountState, address) do
      nil ->
        %AccountState{
          address: address,
          balance: D.new(0),
          nonce: 0,
          storage_root: "",
          code_hash: ""
        }

      state ->
        Map.merge(state, %{address: address})
    end
  end

  @doc """
  Creates/updates an account_state.
  """
  def write_account_state(trie, attrs) do
    MPT.Repo.write(trie, AccountState, attrs)
  end

  @doc """
  Calculates world state for the given block_number or transactions, returns error code on fail.
  """
  def calculate_world_state(arg) do
    try do
      {:ok, calculate_world_state!(arg)}
    rescue
      State.MissingBlockBodyError -> {:error, :missing_block_body}
      State.DbAccessError -> {:error, :db_inaccessible}
      State.InvalidStateError -> {:error, :invalid_state}
      State.InvalidRootError -> {:error, :invalid_root}
    end
  end

  @doc """
  Calculates world state for the given block_number, raises errors on fail.
  """
  def calculate_world_state!(end_block_number) when is_integer(end_block_number) do
    case last_existing_state(end_block_number) do
      {start_root, ^end_block_number} ->
        start_root

      {start_root, start_block_number} ->
        calculate_world_state!(start_root, start_block_number, end_block_number)
    end
  end

  @doc """
  Calculates world state for the given list of transactions, raises errors on fail.
  """
  def calculate_world_state!(txs) when is_list(txs) do
    end_block_number = Blockchain.last_confirmed_block_number()
    {start_root, start_block_number} = last_existing_state(end_block_number)

    start_root =
      if start_block_number == end_block_number do
        start_root
      else
        calculate_world_state!(start_root, start_block_number, end_block_number)
      end

    calculate_world_state!(start_root, txs)
  end

  defp calculate_world_state!(start_root, start_block_number, end_block_number) do
    blk = Blockchain.get_block_by_number(end_block_number)

    blks =
      blk
      |> Blockchain.list_preceding_blocks()
      |> filter_blocks_by_number(start_block_number)
      |> List.insert_at(0, blk)

    txs =
      blks
      |> Enum.map(fn blk ->
        case Blockchain.list_transactions(blk) do
          [] -> raise MissingBlockBodyError
          txs -> txs
        end
      end)
      |> List.flatten()

    calculate_world_state!(start_root, txs)
  end

  defp calculate_world_state!(start_root, txs) do
    trie =
      Enum.reduce(txs, state_trie(start_root), fn tx, trie ->
        from = Pool.get_transaction_from_address(tx)
        from_account_state = get_account_state(trie, from)
        from_nonce = tx.nonce + 1

        # HACK: testnet may contain accounts with effectively negative balance, storing them as 0
        #   instead as we (technically) can't store negative numbers; to be removed after moving
        #   to mainnet
        from_balance =
          from_account_state.balance
          |> D.sub(tx.value)
          |> D.max(0)

        {:ok, trie, _account_state} =
          write_account_state(trie, %{
            from_account_state
            | balance: from_balance,
              nonce: from_nonce
          })

        to = tx.to
        to_account_state = get_account_state(trie, to)
        to_balance = D.add(to_account_state.balance, tx.value)

        {:ok, trie, _account_state} =
          write_account_state(trie, %{to_account_state | balance: to_balance})

        trie
      end)

    Exleveldb.close(elem(trie.db, 1))

    Base.encode16(trie.root_hash)
  end

  defp last_existing_state(block_number) do
    case Blockchain.get_block_by_number(block_number) do
      nil ->
        {nil, 0}

      # TODO: backwards-compatibility block, only possible on the current testnet version,
      #   to be removed after moving to mainnet
      %{state_root: ""} ->
        {nil, 0}

      %{hash: hash, state_root: root} ->
        trie = state_trie(root)

        cond do
          trie == {:error, :db_inaccessible} ->
            raise DbAccessError

          trie == {:error, :invalid_root} ->
            raise InvalidRootError, state_root: root, hash: hash

          Trie.Node.decode_trie(trie) == :empty ->
            Exleveldb.close(elem(trie.db, 1))
            if block_number > 0, do: last_existing_state(block_number - 1), else: nil

          true ->
            Exleveldb.close(elem(trie.db, 1))
            {root, block_number}
        end
    end
  end

  def state_trie(state_root), do: MPT.RepoManager.trie("state", "state", state_root)

  defp filter_blocks_by_number(blocks, start_block_number) when start_block_number == 0,
    do: Enum.filter(blocks, &(&1.number >= start_block_number))

  defp filter_blocks_by_number(blocks, start_block_number),
    do: Enum.filter(blocks, &(&1.number > start_block_number))
end

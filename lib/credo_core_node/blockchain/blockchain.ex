defmodule CredoCoreNode.Blockchain do
  @moduledoc """
  The Blockchain context.
  """

  alias CredoCoreNode.Blockchain.{Block, Transaction}
  alias CredoCoreNode.Pool
  alias Mnesia.Repo

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
    Repo.list(Transaction)
  end

  @doc """
  Gets a single transaction.
  """
  def get_transaction(hash) do
    Repo.get(Transaction, hash)
  end

  @doc """
  Creates/updates a transaction.
  """
  def write_transaction(attrs) do
    Repo.write(Transaction, attrs)
  end

  @doc """
  Deletes a transaction.
  """
  def delete_transaction(%Transaction{} = transaction) do
    Repo.delete(transaction)
  end

  @doc """
  Returns the list of blocks.
  """
  def list_blocks() do
    Repo.list(Block)
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
    {:ok, block} = # TODO: load actual genesis block.
      write_block(%{number: 0, hash: "0xe454d0d47a6e45ccd055dcc31e319d71da1063e5d2073aadb44e9d6e602b1916"})

    block
  end

  @doc """
  Gets a single block.
  """
  def get_block(hash) do
    Repo.get(Block, hash)
  end

  def get_block_by_number(number) do
    list_blocks()
    |> Enum.filter(&(&1.number == number))
    |> List.first()
  end

  @doc """
  Creates/updates a block.
  """
  def write_block(attrs) do
    Repo.write(Block, attrs)
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
    Repo.delete(block)
  end

  def propagate_block(block) do
    Network.notify_connected_nodes(block, :create)

    {:ok, block}
  end
end

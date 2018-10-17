defmodule CredoCoreNode.Blockchain do
  @moduledoc """
  The Blockchain context.
  """

  alias CredoCoreNode.Blockchain.Transaction
  alias CredoCoreNode.Blockchain.Block
  alias Mnesia.Repo

  def coinbase_tx_type, do: "coinbase"
  def security_deposit_tx_type, do: "security_deposit"
  def update_validator_ip_tx_type, do: "update_validator_ip"

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
  Gets a single block.
  """
  def get_block(hash) do
    Repo.get(Block, hash)
  end

  @doc """
  Gets a single block by the number.
  """
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

  TODO: add some kind of status field for marking blocks as invalid.
  """
  def mark_block_as_invalid(block) do
  end

  @doc """
  Deletes a block.
  """
  def delete_block(%Block{} = block) do
    Repo.delete(block)
  end

  @doc """
  Returns candidate blocks for a given block number.
  """
  def list_block_candidates(number) do
    list_blocks()
    |> Enum.filter(&(&1.number == number))
  end
end

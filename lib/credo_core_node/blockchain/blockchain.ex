defmodule CredoCoreNode.Blockchain do
  @moduledoc """
  The Blockchain context.
  """

  alias CredoCoreNode.Blockchain.Transaction
  alias CredoCoreNode.Blockchain.Block
  alias Mnesia.Repo

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
  Creates/updates a block.
  """
  def write_block(attrs) do
    Repo.write(Block, attrs)
  end

  @doc """
  Deletes a block.
  """
  def delete_block(%Block{} = block) do
    Repo.delete(block)
  end
end

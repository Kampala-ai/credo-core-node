defmodule CredoCoreNode.Blockchain do
  @moduledoc """
  The Blockchain context.
  """

  alias CredoCoreNode.Blockchain.Block
  alias CredoCoreNode.Blockchain.Transaction
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
  Generates a block.
  """
  def generate_block(transactions) do
    last_block =
      list_blocks()
      |> Enum.sort(&(&1.number > &2.number))
      |> List.first()

    {number, prev_hash} =
      if last_block, do: {last_block.number + 1, last_block.hash}, else: {0, ""}

    body = ExRLP.encode(transactions, encoding: :hex)
    tx_root =
      body
      |> :libsecp256k1.sha256()
      |> Base.encode16()

    block = %Block{
      prev_hash: prev_hash,
      number: number,
      state_root: "",
      receipt_root: "",
      tx_root: tx_root,
      body: body
    }

    Map.put(block, :hash, Block.hash(block, encoding: :hex))
  end

  @doc """
  Returns candidate blocks for a given block number.
  """
  def list_block_candidates(number) do
    list_blocks()
    |> Enum.filter(&(&1.number == number))
  end
end

defmodule CredoCoreNode.Blockchain do
  @moduledoc """
  The Blockchain context.
  """

  alias CredoCoreNode.Blockchain.Block
  alias CredoCoreNode.Blockchain.Transaction
  alias CredoCoreNode.Pool
  alias CredoCoreNode.Validation
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
  Broadcasts a block to validators
  """
  def broadcast_block_to_validators(block) do
  end

  @doc """
  Gets the next block producer.

  #TODO weight by stake size and participation rate.
  """
  def get_next_block_producer(last_block) do
    number = last_block.number + 1

    # Seed rand with the current block number to produce a deterministic, pseudorandom result.
    :rand.seed(:exsplus, {101, 102, number})

    index =
      Enum.random(1..Validation.count_validators())

    Validation.list_validators()
    |> Enum.sort( &(&1.address >= &2.address) )
    |> Enum.at(index)
  end

  @doc """
  Adds a transaction to pay transaction fees to the block producer.
  """
  def add_tx_fee_block_producer_reward_transaction(transactions) do
    transactions
  end

  @doc """
  Produces the next block if its the node's turn.

  To be called after a block is confirmed.
  """
  def maybe_produce_next_block(confirmed_block) do
    if Validation.is_validator?() && get_next_block_producer(confirmed_block) == Validation.get_own_validator() do
      Pool.get_batch_of_pending_transactions()
      |> add_tx_fee_block_producer_reward_transaction()
      |> generate_block()
      |> broadcast_block_to_validators()
    end
  end
end

defmodule CredoCoreNode.Mining do
  @moduledoc """
  The Validation context.
  """

  alias CredoCoreNode.Blockchain.BlockProducer
  alias CredoCoreNode.Mining.DepositManager
  alias CredoCoreNode.Mining.Miner
  alias CredoCoreNode.Mining.Vote

  alias Mnesia.Repo

  @default_nonce 0
  @default_tx_fee 0.1
  @min_stake_size 10000

  def default_nonce, do: @default_nonce
  def default_tx_fee, do: @default_tx_fee
  def min_stake_size, do: @min_stake_size

  @doc """
  Makes a node become a miner.

  amount is the security deposit size
  to is the address in which the security deposit will be held
  timelock is the duration that the security deposit will be deposited for
  """
  def become_miner(amount, private_key, to, timelock \\ nil) do
    unless is_miner?() do
      DepositManager.construct_security_deposit(amount, private_key, to, timelock)
      |> DepositManager.broadcast_security_deposit()
    end
  end

  @doc """
  Deletes a miner when it has an insufficient stake.

  This should be called after a miner has been slashed and after a security deposit withdrawal has occurred.
  """
  def delete_miner_for_insufficient_stake(miner) do
    if miner.stake_amount < @min_stake_size do
      delete_miner(miner)
    end
  end

  @doc """
  Returns whether the current node is already a miner.
  """
  def get_own_miner() do
    list_miners()
    |> Enum.filter(& &1.is_self)
    |> List.first()
  end

  @doc """
  Returns whether the current node is already a miner.
  """
  def is_miner?() do
    list_miners()
    |> Enum.filter(& &1.is_self)
    |> Enum.any?
  end

  @doc """
  Returns the list of miners.
  """
  def list_miners() do
    Repo.list(Miner)
  end

  @doc """
  Returns the number of miners.
  """
  def count_miners() do
    length(Repo.list(Miner))
  end

  @doc """
  Gets a single miner.
  """
  def get_miner(address) do
    Repo.get(Miner, address)
  end

  @doc """
  Creates/updates a miner.
  """
  def write_miner(attrs) do
    Repo.write(Miner, attrs)
  end

  @doc """
  Deletes a miner.
  """
  def delete_miner(%Miner{} = miner) do
    Repo.delete(miner)
  end

  @doc """
  Returns the list of votes.
  """
  def list_votes() do
    Repo.list(Vote)
  end

  @doc """
  Returns the list of votes for a given round.
  """
  def list_votes_for_round(block, voting_round) do
    list_votes()
    |> Enum.filter(& &1.number == block.number)
    |> Enum.filter(& &1.voting_round == voting_round)
  end

  @doc """
  Gets a single vote.
  """
  def get_vote(block_hash) do
    Repo.get(Vote, block_hash)
  end

  @doc """
  Creates/updates a vote.
  """
  def write_vote(attrs) do
    Repo.write(Vote, attrs)
  end

  @doc """
  Deletes a vote.
  """
  def delete_vote(%Vote{} = vote) do
    Repo.delete(vote)
  end

  def start_mining(block, retry_count \\ 0) do
    if BlockProducer.is_your_turn?(block, retry_count) do
      BlockProducer.produce_block()
    else
      BlockProducer.wait_for_block(block, retry_count)
    end
  end
end
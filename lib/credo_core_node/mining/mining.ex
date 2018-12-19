defmodule CredoCoreNode.Mining do
  @moduledoc """
  The Mining context.
  """

  alias CredoCoreNode.Accounts
  alias CredoCoreNode.Blockchain.{BlockProducer, BlockValidator}
  alias CredoCoreNode.Mining.{Deposit, Miner, Slash, Vote, VoteManager}
  alias CredoCoreNode.Pool

  alias Mnesia.Repo

  alias Decimal, as: D

  require Logger

  @default_nonce 0
  @default_tx_fee 1.0
  @min_stake_size D.new(10000)
  @vote_waiting_intervals 50
  @max_timelock_block_height 500_000_000

  def default_nonce, do: @default_nonce
  def default_tx_fee, do: @default_tx_fee
  def min_stake_size, do: @min_stake_size

  def become_miner(amount, private_key, to, timelock \\ nil) do
    unless is_miner?() do
      Deposit.construct_deposit(amount, private_key, to, timelock)
      |> Pool.propagate_pending_transaction()
    end
  end

  def delete_miner_for_insufficient_stake(miner) do
    if D.cmp(miner.stake_amount, @min_stake_size) == :lt, do: delete_miner(miner)
  end

  def my_miner() do
    list_miners()
    |> Enum.filter(& &1.is_self)
    |> List.first()
  end

  def withdrawable_deposit_value(miner, block) do
    list_deposits()
    |> Enum.filter(&(&1.miner_address == miner.address))
    |> Enum.filter(&timelock_has_expired?(&1.timelock, block))
    |> Enum.reduce(D.new(0), fn deposit, acc ->
      D.add(deposit.amount, acc)
    end)
    |> Decimal.min(Accounts.get_account_balance(miner.address))
  end

  @doc """
  Returns whether the current node is already a miner.
  """
  def is_miner?() do
    list_miners()
    |> Enum.filter(& &1.is_self)
    |> Enum.any?()
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
    |> Enum.filter(&(&1.block_number == block.number))
    |> Enum.filter(&(&1.voting_round == voting_round))
  end

  @doc """
  Gets a single vote.
  """
  def get_vote(hash) do
    Repo.get(Vote, hash)
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

  @doc """
  Returns the list of slashes.
  """
  def list_slashes() do
    Repo.list(Slash)
  end

  @doc """
  Gets a single slash.
  """
  def get_slash(hash) do
    Repo.get(Slash, hash)
  end

  @doc """
  Creates/updates a slash.
  """
  def write_slash(attrs) do
    Repo.write(Slash, attrs)
  end

  @doc """
  Deletes a slash.
  """
  def delete_slash(%Slash{} = slash) do
    Repo.delete(slash)
  end

  @doc """
  Returns the list of deposits.
  """
  def list_deposits() do
    Repo.list(Deposit)
  end

  @doc """
  Gets a single deposit.
  """
  def get_deposit(hash) do
    Repo.get(Deposit, hash)
  end

  def timelock_is_block_height?(timelock),
    do: timelock > 0 && timelock < @max_timelock_block_height

  def timelock_has_expired?(timelock, block) when is_bitstring(timelock), do: true

  def timelock_has_expired?(timelock, block) do
    if timelock_is_block_height?(timelock) do
      block.number >= timelock
    else
      DateTime.compare(DateTime.utc_now(), DateTime.from_unix!(timelock)) != :lt
    end
  end

  @doc """
  Creates/updates a deposit.
  """
  def write_deposit(attrs) do
    Repo.write(Deposit, attrs)
  end

  @doc """
  Deletes a deposit.
  """
  def delete_deposit(%Deposit{} = deposit) do
    Repo.delete(deposit)
  end

  def start_mining(block, retry_count \\ 0) do
    if BlockProducer.is_your_turn?(block, retry_count) do
      case BlockProducer.produce_block() do
        {:ok, block} ->
          BlockValidator.validate_block(block)

        {:error, :no_pending_txs} ->
          Logger.info("No pending txs...")
      end
    else
      BlockProducer.wait_for_block(block, retry_count)
    end
  end

  def start_voting(block, voting_round \\ 0) do
    Logger.info("Started voting at block height #{block.number} in round #{voting_round}.")

    unless VoteManager.already_voted?(block, voting_round) do
      VoteManager.cast_vote(block, voting_round)
      VoteManager.wait_for_votes(block, voting_round, @vote_waiting_intervals)
    end

    VoteManager.consensus_reached?(block, voting_round)
  end
end

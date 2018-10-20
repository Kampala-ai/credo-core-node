defmodule CredoCoreNode.Mining do
  @moduledoc """
  The Validation context.
  """

  alias CredoCoreNode.Mining.SecurityDeposits
  alias CredoCoreNode.Mining.Validator
  alias CredoCoreNode.Mining.Vote

  alias Mnesia.Repo

  @default_nonce 0
  @default_tx_fee 0.1
  @min_stake_size 10000

  def default_nonce, do: @default_nonce
  def default_tx_fee, do: @default_tx_fee
  def min_stake_size, do: @min_stake_size

  @doc """
  Makes a node become a validator.

  amount is the security deposit size
  to is the address in which the security deposit will be held
  timelock is the duration that the security deposit will be deposited for
  """
  def become_validator(amount, private_key, to, timelock \\ nil) do
    unless is_validator?() do
      SecurityDeposits.construct_security_deposit(amount, private_key, to, timelock)
      |> SecurityDeposits.broadcast_security_deposit()
    end
  end

  @doc """
  Deletes a validator when it has an insufficient stake.

  This should be called after a validator has been slashed and after a security deposit withdrawal has occurred.
  """
  def delete_validator_for_insufficient_stake(validator) do
    if validator.stake_amount < @min_stake_size do
      delete_validator(validator)
    end
  end

  @doc """
  Returns whether the current node is already a validator.
  """
  def get_own_validator() do
    list_validators()
    |> Enum.filter(& &1.is_self)
    |> List.first()
  end

  @doc """
  Returns whether the current node is already a validator.
  """
  def is_validator?() do
    list_validators()
    |> Enum.filter(& &1.is_self)
    |> Enum.any?
  end

  @doc """
  Returns the list of validators.
  """
  def list_validators() do
    Repo.list(Validator)
  end

  @doc """
  Returns the number of validators.
  """
  def count_validators() do
    length(Repo.list(Validator))
  end

  @doc """
  Gets a single validator.
  """
  def get_validator(address) do
    Repo.get(Validator, address)
  end

  @doc """
  Creates/updates a validator.
  """
  def write_validator(attrs) do
    Repo.write(Validator, attrs)
  end

  @doc """
  Deletes a validator.
  """
  def delete_validator(%Validator{} = validator) do
    Repo.delete(validator)
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
end
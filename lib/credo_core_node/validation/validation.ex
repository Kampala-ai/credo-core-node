defmodule CredoCoreNode.Validation do
  @moduledoc """
  The Validation context.
  """

  alias CredoCoreNode.SecurityDeposits
  alias CredoCoreNode.Validation.Validator
  alias CredoCoreNode.Validation.Vote

  alias Mnesia.Repo

  @min_stake_size 10000
  @default_nonce 0
  @default_tx_fee 0.1

  # TODO: specify actual timelock limits.
  @min_timelock 1
  @max_timelock 100

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
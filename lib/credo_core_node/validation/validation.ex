defmodule CredoCoreNode.Validation do
  @moduledoc """
  The Validation context.
  """

  alias CredoCoreNode.Validation.Validator
  alias CredoCoreNode.Validation.Vote

  alias Mnesia.Repo

  @min_stake_size 10000

  @doc """
  Returns the list of validators.
  """
  def list_validators() do
    Repo.list(Validator)
  end

  @doc """
  Gets a single validator.
  """
  def get_validator(hash) do
    Repo.get(Validator, hash)
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
end
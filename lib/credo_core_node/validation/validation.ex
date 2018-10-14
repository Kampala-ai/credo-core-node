defmodule CredoCoreNode.Validation do
  @moduledoc """
  The Validation context.
  """

  alias CredoCoreNode.Network
  alias CredoCoreNode.Pool
  alias CredoCoreNode.SecurityDeposits
  alias CredoCoreNode.Validation.Validator
  alias CredoCoreNode.Validation.Vote

  alias Mnesia.Repo

  @min_stake_size 10000
  @default_nonce 0
  @default_tx_fee 0.1

  def default_nonce do
    @default_nonce
  end

  def default_tx_fee do
    @default_tx_fee
  end

  def min_stake_size do
    @min_stake_size
  end

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
  Check whether the node's ip has changed compared with the validator state
  """
  def validator_ip_changed? do
    Network.get_current_ip != get_own_validator().node_ip
  end

  @doc """
  Update the validator's ip if it has changed.
  """
  def maybe_update_validator_ip do
    if is_validator?() && validator_ip_changed?() do
      private_key = "" #TODO get actual private key

      construct_validator_ip_update_transaction(private_key, get_own_validator().address)
      |> broadcast_validator_ip_update_transaction()
    end
  end

  @doc """
  Constructs a security deposit transaction.
  """
  def construct_validator_ip_update_transaction(private_key, to) do
    ip = Network.get_current_ip()

    attrs = %{nonce: @default_nonce, to: to, value: 0 , fee: @default_tx_fee, data: "{\"tx_type\" : \"update_validator_ip\", \"node_ip\" : \"#{ip}\"}"}

    {:ok, tx} = Pool.generate_pending_transaction(private_key, attrs)

    tx
  end

  @doc """
  Broadcasts a validator ip update transaction.
  """
  def broadcast_validator_ip_update_transaction(tx) do
    Pool.propagate_pending_transaction(tx)
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
defmodule CredoCoreNode.Validation do
  @moduledoc """
  The Validation context.
  """

  alias CredoCoreNode.Network
  alias CredoCoreNode.Pool
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
      construct_security_deposit(amount, private_key, to, timelock)
      |> broadcast_security_deposit()
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

  @doc """
  Constructs a security deposit transaction.
  """
  def construct_security_deposit(amount, private_key, to, timelock \\ nil) do
    ip = Network.get_current_ip()

    attrs = %{nonce: @default_nonce, to: to, value: amount , fee: @default_tx_fee, data: "{\"tx_type\" : \"security_deposit\", \"node_ip\" : \"#{ip}\", \"timelock\": \"#{timelock}\"}"}

    {:ok, tx} = Pool.generate_pending_transaction(private_key, attrs)

    tx
  end

  @doc """
  Broadcasts a security deposit transaction.
  """
  def broadcast_security_deposit(tx) do
    Pool.propagate_pending_transaction(tx)
  end

  @doc """
  Checks whether a transaction is a security deposit
  """
  def is_security_deposit(tx) do
    Poison.decode!(tx.data)["tx_type"] == "security_deposit"
  end

  @doc """
  Returns a list of valid security deposits
  """
  def validate_security_deposits(txs) do
    txs
    |> Enum.filter(& validate_security_deposit_size(&1))
    |> Enum.filter(& validate_security_deposit_timelock(&1))
  end

  @doc """
  Validates the security deposit size.
  """
  def validate_security_deposit_size(tx) do
    tx.value >= @min_stake_size
  end

  @doc """
  Validates the security deposit timelock.
  """
  def validate_security_deposit_timelock(tx) do
    timelock = Poison.decode!(tx.data)["timelock"]

    timelock >= @min_timelock && timelock <= @max_timelock
  end

  @doc """
  Returns security deposits from a list of transactions
  """
  def get_security_deposits(txs) do
    txs
    |> Enum.filter(& is_security_deposit(&1))
  end

  @doc """
  Creates validators based on security deposit information
  """
  def process_security_deposits(txs) do
    for tx <- txs do
      unless get_validator(tx.to) do
        node_ip = Poison.decode!(tx.data)["node_ip"]

        %{ip: node_ip, address: tx.to, stake_amount: tx.value, participation_rate: 1, is_self: false}
        |> write_validator
      end
    end
  end

  @doc """
  Retrieves, validates, and processes security deposits.

  To be called after a block is confirmed.
  """
  def maybe_process_security_deposits(txs) do
    txs
    |> get_security_deposits()
    |> validate_security_deposits()
    |> process_security_deposits()
  end
end
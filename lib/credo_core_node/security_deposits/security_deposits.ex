defmodule CredoCoreNode.SecurityDeposits do
  @moduledoc """
  The security deposits context.
  """

  alias CredoCoreNode.Network
  alias CredoCoreNode.Pool
  alias CredoCoreNode.Validation

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
      unless Validation.get_validator(tx.to) do
        node_ip = Poison.decode!(tx.data)["node_ip"]

        %{ip: node_ip, address: tx.to, stake_amount: tx.value, participation_rate: 1, is_self: false}
        |> Validation.write_validator
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
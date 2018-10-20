defmodule CredoCoreNode.Mining.DepositManager do
  @moduledoc """
  The security deposit manager module.
  """

  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Network
  alias CredoCoreNode.Pool
  alias CredoCoreNode.Mining

  # TODO: specify actual timelock limits.
  @min_timelock 1
  @max_timelock 100

  @doc """
  Constructs a security deposit transaction.
  """
  def construct_security_deposit(amount, private_key, to, timelock \\ nil) do
    {:ok, tx} = Pool.generate_pending_transaction(private_key, %{
      nonce: Mining.default_nonce(),
      to: to,
      value: amount,
      fee: Mining.default_tx_fee(),
      data: "{\"tx_type\" : \"#{Blockchain.security_deposit_tx_type()}\", \"node_ip\" : \"#{Network.get_current_ip()}\", \"timelock\": \"#{timelock}\"}"
    })

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
    Poison.decode!(tx.data)["tx_type"] == Blockchain.security_deposit_tx_type()
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
    tx.value >= Mining.min_stake_size()
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
  Creates miners based on security deposit information
  """
  def process_security_deposits(txs) do
    for tx <- txs do
      unless Mining.get_miner(tx.to) do
        node_ip = Poison.decode!(tx.data)["node_ip"]

        %{ip: node_ip, address: tx.to, stake_amount: tx.value, participation_rate: 1, is_self: false}
        |> Mining.write_miner
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

  @doc """
  Checks whether a transaction is a security deposit withdrawal
  """
  def is_security_deposit_withdrawal(tx) do
    tx.from
    |> Mining.get_miner()
    |> is_nil
    |> Kernel.not
  end

  @doc """
  Returns security deposit withdrawals from a list of transactions
  """
  def get_security_deposit_withdrawals(txs) do
    txs
    |> Enum.filter(& is_security_deposit_withdrawal(&1))
  end

  @doc """
  Validates the security deposit withdrawal size.
  """
  def validate_security_deposit_withdrawal_size(tx, miner) do
    tx.value <= miner.stake_amount
  end

  @doc """
  Validates the security deposit withdrawal timelock.
  """
  def validate_security_deposit_withdrawal_timelock(tx, miner) do
    tx.block_number <= miner.timelock # TODO Add function for getting a transaction's block number.
  end

  @doc """
  Gets validate the security deposit timelock.
  """
  def get_invalid_security_deposit_withdrawals(txs) do
    txs
    |> Enum.filter(& !validate_security_deposit_withdrawal_size(&1, Mining.get_miner(&1.address)))
    |> Enum.filter(& !validate_security_deposit_withdrawal_timelock(&1, Mining.get_miner(&1.address)))
  end

  @doc """
  Checks whether a list of transactions contains any invalid security deposit withdrawals

  Used to reject a block that has invalid security deposit withdrawals.
  """
  def maybe_validate_security_deposit_withdrawals(txs) do
    txs
    |> get_security_deposit_withdrawals()
    |> get_invalid_security_deposit_withdrawals()
    |> Enum.any?
  end
end
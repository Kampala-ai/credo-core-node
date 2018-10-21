defmodule CredoCoreNode.Mining.Deposit do
  alias CredoCoreNode.{Blockchain, Network, Pool, Mining}

  @min_timelock 1 # TODO: specify actual timelock limits.
  @max_timelock 100

  def construct_deposit(amount, private_key, to, timelock \\ nil) do
    {:ok, tx} = Pool.generate_pending_transaction(private_key, %{
      nonce: Mining.default_nonce(),
      to: to,
      value: amount,
      fee: Mining.default_tx_fee(),
      data: "{\"tx_type\" : \"#{Blockchain.security_deposit_tx_type()}\", \"node_ip\" : \"#{Network.get_current_ip()}\", \"timelock\": \"#{timelock}\"}"
    })

    tx
  end

  def maybe_recognize_deposits(block) do
    block.transactions
    |> parse_deposits()
    |> validate_deposits()
    |> recognize_deposits()
  end

  def parse_deposits(txs) do
    txs
    |> Enum.filter(& is_deposit(&1))
  end

  def is_deposit(tx) do
    Poison.decode!(tx.data)["tx_type"] == Blockchain.security_deposit_tx_type()
  end

  def validate_deposits(deposits) do
    deposits
    |> Enum.filter(& validate_deposit_size(&1))
    |> Enum.filter(& validate_deposit_timelock(&1))
  end

  def validate_deposit_size(tx) do
    tx.value >= Mining.min_stake_size()
  end

  def validate_deposit_timelock(tx) do
    timelock = Poison.decode!(tx.data)["timelock"]

    timelock >= @min_timelock && timelock <= @max_timelock
  end

  def miner_already_exists?(deposit) do
    deposit.from
    |> Mining.get_miner()
    |> is_nil
    |> Kernel.not
  end

  def recognize_deposits(deposits) do
    Enum.each deposits, fn deposit ->
      unless miner_already_exists?(deposit) do
        Mining.write_miner(%{
          ip: Poison.decode!(deposit.data)["node_ip"],
          address: deposit.to,
          stake_amount: deposit.value,
          participation_rate: 1,
          is_self: false
        })
      end
    end
  end
end
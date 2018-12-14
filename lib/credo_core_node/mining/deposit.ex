defmodule CredoCoreNode.Mining.Deposit do
  use Mnesia.Schema,
    table_name: :deposits,
    fields: [:tx_hash, :miner_address, :amount, :timelock]

  alias CredoCoreNode.{Blockchain, Network, Pool, Mining}

  alias Decimal, as: D

  # TODO: specify actual timelock limits.
  @min_timelock 1
  @max_timelock 100

  def construct_deposit(amount, private_key, to, timelock \\ nil) do
    {:ok, tx} =
      Pool.generate_pending_transaction(private_key, %{
        nonce: Mining.default_nonce(),
        to: to,
        value: amount,
        fee: Mining.default_tx_fee(),
        data:
          "{\"tx_type\" : \"#{Blockchain.security_deposit_tx_type()}\", \"node_ip\" : \"#{
            Network.get_current_ip()
          }\", \"timelock\": \"#{timelock}\"}"
      })

    tx
  end

  def maybe_recognize_deposits(block) do
    block
    |> Blockchain.list_transactions()
    |> parse_deposits()
    |> validate_deposits()
    |> recognize_deposits()
  end

  def parse_deposits(txs) do
    Enum.filter(txs, &is_deposit(&1))
  end

  def is_deposit(tx) do
    String.length(tx.data) > 1 &&
      Poison.decode!(tx.data)["tx_type"] == Blockchain.security_deposit_tx_type()
  end

  def validate_deposits(deposits) do
    deposits
    |> Enum.filter(&validate_deposit_size(&1))
    |> Enum.filter(&validate_deposit_timelock(&1))
  end

  def validate_deposit_size(tx) do
    D.cmp(tx.value, D.new(Mining.min_stake_size())) != :lt
  end

  def parse_timelock(tx) do
    Poison.decode!(tx.data)["timelock"]
  end

  def validate_deposit_timelock(tx) do
    timelock = parse_timelock(tx)

    # use emtpy string for default timelock
    String.length(timelock) == 0 || (timelock >= @min_timelock && timelock <= @max_timelock)
  end

  def get_miner_for_deposit(deposit) do
    deposit
    |> Pool.get_transaction_from_address()
    |> Mining.get_miner()
  end

  def miner_already_exists?(deposit) do
    deposit
    |> get_miner_for_deposit()
    |> is_nil
    |> Kernel.not()
  end

  def recognize_deposits(deposits) do
    Enum.each(deposits, fn deposit ->
      case get_miner_for_deposit(deposit) do
        nil ->
          %{
            ip: Poison.decode!(deposit.data)["node_ip"],
            address: deposit.to,
            stake_amount: deposit.value,
            participation_rate: 1,
            is_self: Poison.decode!(deposit.data)["node_ip"] == Network.get_current_ip()
          }

        miner ->
          %{miner | stake_amount: Decimal.add(miner.stake_amount, deposit.value)}
      end
      |> CredoCoreNode.Mining.write_miner()

      Mining.write_deposit(%{
        tx_hash: deposit.hash,
        miner_address: deposit.to,
        amount: deposit.value,
        timelock: parse_timelock(deposit)
      })
    end)
  end
end

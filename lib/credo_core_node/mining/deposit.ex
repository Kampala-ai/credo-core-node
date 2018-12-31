defmodule CredoCoreNode.Mining.Deposit do
  use Mnesia.Schema,
    table_name: :deposits,
    fields: [:tx_hash, :miner_address, :amount, :timelock]

  alias CredoCoreNode.{Blockchain, Network, Pool, Mining}

  alias Decimal, as: D

  @behaviour CredoCoreNode.Adapters.DepositAdapter

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
          Poison.encode!(%{
            tx_type: Blockchain.security_deposit_tx_type(),
            node_ip: Network.get_current_ip(),
            timelock: "#{timelock}"
          })
      })

    tx
  end

  def maybe_recognize_deposits(block) do
    block
    |> Blockchain.list_transactions()
    |> parse_deposits()
    |> valid_deposits?()
    |> recognize_deposits()
  end

  defp parse_deposits(txs) do
    Enum.filter(txs, &is_deposit(&1))
  end

  def is_deposit(%{data: nil} = _tx), do: false
  def is_deposit(%{data: data} = _tx) when not is_binary(data), do: false

  def is_deposit(%{data: data} = tx) when is_binary(data) do
    try do
      tx.data =~ "tx_type" &&
        Poison.decode!(tx.data)["tx_type"] == Blockchain.security_deposit_tx_type()
    rescue
      Poison.SyntaxError -> false
    end
  end

  def valid_deposits?(deposits) do
    deposits
    |> Enum.filter(&valid_deposit_size?(&1))
    |> Enum.filter(&valid_deposit_timelock?(&1))
    |> Enum.filter(&valid_deposit_node_ip?(&1))
  end

  defp valid_deposit_size?(tx) do
    D.cmp(tx.value, Mining.min_stake_size()) != :lt
  end

  defp valid_deposit_node_ip?(tx) do
    node_ip = parse_node_ip(tx)

    !is_nil(node_ip) && node_ip != ""
  end

  defp parse_timelock(%{data: nil} = _tx), do: nil
  defp parse_timelock(%{data: data} = _tx) when not is_binary(data), do: nil

  defp parse_timelock(%{data: data} = tx) when is_binary(data) do
    try do
      tx.data =~ "timelock" && Poison.decode!(tx.data)["timelock"]
    rescue
      Poison.SyntaxError -> nil
    end
  end

  defp parse_node_ip(%{data: nil} = _tx), do: nil
  defp parse_node_ip(%{data: data} = _tx) when not is_binary(data), do: nil

  defp parse_node_ip(%{data: data} = tx) when is_binary(data) do
    try do
      tx.data =~ "node_ip" && Poison.decode!(tx.data)["node_ip"]
    rescue
      Poison.SyntaxError -> nil
    end
  end

  defp valid_deposit_timelock?(tx) do
    timelock = parse_timelock(tx)

    # use emtpy string for default timelock
    String.length(timelock) == 0 || (timelock >= @min_timelock && timelock <= @max_timelock)
  end

  defp get_miner_for_deposit(deposit) do
    deposit
    |> Pool.get_transaction_from_address()
    |> Mining.get_miner()
  end

  def recognize_deposits(deposits) do
    Enum.map(deposits, fn deposit ->
      case get_miner_for_deposit(deposit) do
        nil ->
          %{
            ip: parse_node_ip(deposit),
            address: deposit.to,
            stake_amount: deposit.value,
            participation_rate: 1,
            inserted_at: DateTime.utc_now(),
            is_self: parse_node_ip(deposit) == Network.get_current_ip()
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

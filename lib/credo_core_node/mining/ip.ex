defmodule CredoCoreNode.Mining.Ip do
  alias CredoCoreNode.{Accounts, Blockchain, Mining, Network, Pool}

  def maybe_update_miner_ip do
    if Mining.is_miner?() && miner_ip_changed?() do
      construct_miner_ip_update_transaction("", Mining.my_miner().address)
      |> Pool.propagate_pending_transaction()
    end
  end

  def miner_ip_changed? do
    # TODO: Make this check more robust. :inet.getif may return ips in a different order, but we're just selecting the first once.
    Network.get_current_ip() != Mining.my_miner().ip
  end

  def construct_miner_ip_update_transaction(private_key, to) do
    {:ok, tx} =
      Pool.generate_pending_transaction(private_key, %{
        nonce: Mining.default_nonce(),
        to: to,
        value: 0.0,
        fee: Mining.default_tx_fee(),
        data:
          Poison.encode!(%{
            tx_type: Blockchain.update_miner_ip_tx_type(),
            node_ip: Network.get_current_ip()
          })
      })

    tx
  end

  def maybe_update_miner_ips(block) do
    block
    |> Blockchain.list_transactions()
    |> get_miner_ip_updates()
    |> validate_miner_ip_updates()
    |> update_miner_ips()
  end

  def get_miner_ip_updates(txs) do
    Enum.filter(txs, &is_miner_ip_update(&1))
  end

  def is_miner_ip_update(%{data: nil} = _tx), do: false
  def is_miner_ip_update(%{data: data} = _tx) when not is_binary(data), do: false

  def is_miner_ip_update(%{data: data} = tx) when is_binary(data) do
    try do
      tx.data =~ "tx_type" &&
        Poison.decode!(tx.data)["tx_type"] == Blockchain.update_miner_ip_tx_type()
    rescue
      Poison.SyntaxError -> false
    end
  end

  def parse_node_ip(%{data: nil} = _miner_ip_update), do: nil
  def parse_node_ip(%{data: data} = _miner_ip_update) when not is_binary(data), do: nil

  def parse_node_ip(%{data: data} = miner_ip_update) when is_binary(data) do
    try do
      miner_ip_update.data =~ "node_ip" && Poison.decode!(miner_ip_update.data)["node_ip"]
    rescue
      Poison.SyntaxError -> nil
    end
  end

  def is_valid_miner_ip_update?(miner_ip_update) do
    Mining.miner_exists?(miner_ip_update.to) && has_valid_signature?(miner_ip_update)
  end

  def has_valid_signature?(miner_ip_update) do
    {:ok, public_key} = Accounts.calculate_public_key(miner_ip_update)

    Mining.miner_exists?(miner_ip_update.to) &&
      miner_ip_update.to == Accounts.payment_address(public_key)
  end

  def validate_miner_ip_updates(miner_ip_updates) do
    Enum.filter(miner_ip_updates, &is_valid_miner_ip_update?(&1))
  end

  def update_miner_ips(miner_ip_updates) do
    Enum.each(miner_ip_updates, fn miner_ip_update ->
      miner_ip_update.to
      |> Mining.get_miner()
      |> Map.merge(%{ip: parse_node_ip(miner_ip_update)})
      |> Mining.write_miner()
    end)
  end
end

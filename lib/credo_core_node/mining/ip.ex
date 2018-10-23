defmodule CredoCoreNode.Mining.Ip do
  alias CredoCoreNode.{Blockchain, Mining, Network, Pool}

  def maybe_update_miner_ip do
    if Mining.is_miner?() && miner_ip_changed?() do
      construct_miner_ip_update_transaction("", Mining.my_miner().address)
      |> Pool.propagate_pending_transaction()
    end
  end

  def miner_ip_changed? do
    Network.get_current_ip != Mining.my_miner().node_ip # TODO: Make this check more robust. :inet.getif may return ips in a different order, but we're just selecting the first once.
  end

  def construct_miner_ip_update_transaction(private_key, to) do
    {:ok, tx} = Pool.generate_pending_transaction(private_key, %{
      nonce: Mining.default_nonce(),
      to: to,
      value: 0,
      fee: Mining.default_tx_fee(),
      data: "{\"tx_type\" : \"#{Blockchain.update_miner_ip_tx_type()}\", \"node_ip\" : \"#{Network.get_current_ip()}\"}"})

    tx
  end

  def maybe_update_miner_ips(block) do
    block.transactions
    |> get_miner_ip_updates()
    |> validate_miner_ip_updates()
    |> update_miner_ips()
  end

  def get_miner_ip_updates(txs) do
    Enum.filter(txs, & is_miner_ip_update(&1))
  end

  def is_miner_ip_update(tx) do
    Poison.decode!(tx.data)["tx_type"] == Blockchain.update_miner_ip_tx_type()
  end

  def validate_miner_ip_updates(miner_ip_updates) do
    miner_ip_updates #TODO implement signature check.
  end

  def update_miner_ips(miner_ip_updates) do
    Enum.each miner_ip_updates, fn miner_ip_update ->
      miner_ip_update.to
      |> Mining.get_miner()
      |> Map.merge(%{node_ip: Poison.decode!(miner_ip_update.data)["node_ip"]})
      |> Mining.write_miner()
    end
  end
end

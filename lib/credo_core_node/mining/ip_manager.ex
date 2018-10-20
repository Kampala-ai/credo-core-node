defmodule CredoCoreNode.Mining.IpManager do
  @moduledoc """
  The miner IP manager module.
  """

  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Network
  alias CredoCoreNode.Pool
  alias CredoCoreNode.Mining

  def maybe_update_miner_ip do
    if Mining.is_miner?() && ip_changed?() do
      construct_miner_ip_update_transaction("", Mining.get_own_miner().address)
      |> Pool.propagate_pending_transaction()
    end
  end

  @doc """
  Check whether the node's ip has changed compared with the miner state
  """
  def ip_changed? do
    Network.get_current_ip != Mining.get_own_miner().node_ip # TODO: Make this check more robust. :inet.getif may return ips in a different order, but we're just selecting the first once.
  end

  @doc """
  Constructs a security deposit transaction.
  """
  def construct_miner_ip_update_transaction(private_key, to) do
    {:ok, tx} = Pool.generate_pending_transaction(private_key, %{
      nonce: Mining.default_nonce(),
      to: to,
      value: 0,
      fee: Mining.default_tx_fee(),
      data: "{\"tx_type\" : \"#{Blockchain.update_miner_ip_tx_type()}\", \"node_ip\" : \"#{Network.get_current_ip()}\"}"})

    tx
  end

  @doc """
  Checks whether a transaction is a miner ip update transaction
  """
  def is_miner_ip_update_transactions(tx) do
    Poison.decode!(tx.data)["tx_type"] == Blockchain.update_miner_ip_tx_type()
  end

  @doc """
  Returns miner ip update transactions from a list of transactions
  """
  def get_miner_ip_update_transactions(txs) do
    txs
    |> Enum.filter(& is_miner_ip_update_transactions(&1))
  end

  @doc """
  Validates ip update transactions by checking that they are signed by the security deposit owner.
  """
  def validate_miner_ip_update_transactions(txs) do
    txs #TODO implement signature check.
  end

  @doc """
  Updates state of miner ip based on the transaction data.
  """
  def process_miner_ip_update_transactions(txs) do
    for tx <- txs do
      node_ip = Poison.decode!(tx.data)["node_ip"]

      tx.to
      |> Mining.get_miner()
      |> Map.merge(%{node_ip: node_ip})
      |> Mining.write_miner()
    end
  end

  @doc """
  Retrieves, validates, and processes miner ip update transactions.

  To be called after a block is confirmed.
  """
  def maybe_validate_miner_ip_update_transactions(txs) do
    txs
    |> get_miner_ip_update_transactions()
    |> validate_miner_ip_update_transactions()
    |> process_miner_ip_update_transactions()
  end
end

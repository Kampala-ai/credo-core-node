defmodule CredoCoreNode.Mining.IpManager do
  @moduledoc """
  The validator IP manager module.
  """

  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Network
  alias CredoCoreNode.Pool
  alias CredoCoreNode.Mining

  @doc """
  Check whether the node's ip has changed compared with the validator state

  TODO: Make this check more robust. :inet.getif may return ips in a different order, but we're just selecting the first once.
  """
  def validator_ip_changed? do
    Network.get_current_ip != Mining.get_own_validator().node_ip
  end

  @doc """
  Update the validator's ip if it has changed.
  """
  def maybe_update_validator_ip do
    if Mining.is_validator?() && validator_ip_changed?() do
      private_key = "" #TODO get actual private key

      construct_validator_ip_update_transaction(private_key, Mining.get_own_validator().address)
      |> broadcast_validator_ip_update_transaction()
    end
  end

  @doc """
  Constructs a security deposit transaction.
  """
  def construct_validator_ip_update_transaction(private_key, to) do
    ip = Network.get_current_ip()

    attrs = %{nonce: Mining.default_nonce(), to: to, value: 0 , fee: Mining.default_tx_fee(), data: "{\"tx_type\" : \"#{Blockchain.update_validator_ip_tx_type()}\", \"node_ip\" : \"#{ip}\"}"}

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
  Checks whether a transaction is a validator ip update transaction
  """
  def is_validator_ip_update_transactions(tx) do
    Poison.decode!(tx.data)["tx_type"] == Blockchain.update_validator_ip_tx_type()
  end

  @doc """
  Returns validator ip update transactions from a list of transactions
  """
  def get_validator_ip_update_transactions(txs) do
    txs
    |> Enum.filter(& is_validator_ip_update_transactions(&1))
  end

  @doc """
  Validates ip update transactions by checking that they are signed by the security deposit owner.
  """
  def validate_validator_ip_update_transactions(txs) do
    txs #TODO implement signature check.
  end

  @doc """
  Updates state of validator ip based on the transaction data.
  """
  def process_validator_ip_update_transactions(txs) do
    for tx <- txs do
      node_ip = Poison.decode!(tx.data)["node_ip"]

      tx.to
      |> Mining.get_validator()
      |> Map.merge(%{node_ip: node_ip})
      |> Mining.write_validator()
    end
  end

  @doc """
  Retrieves, validates, and processes validator ip update transactions.

  To be called after a block is confirmed.
  """
  def maybe_validate_validator_ip_update_transactions(txs) do
    txs
    |> get_validator_ip_update_transactions()
    |> validate_validator_ip_update_transactions()
    |> process_validator_ip_update_transactions()
  end
end

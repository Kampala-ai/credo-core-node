defmodule CredoCoreNode.Mining.DepositWithdrawal do
  alias CredoCoreNode.Mining
  alias CredoCoreNode.Pool

  def validate_deposit_withdrawals(block) do
    block
    |> Pool.list_pending_transactions()
    |> get_deposit_withdrawals()
    |> get_invalid_deposit_withdrawals()
    |> Enum.empty?
  end

  def get_deposit_withdrawals(txs) do
    Enum.filter(txs, & is_deposit_withdrawal(&1))
  end

  def is_deposit_withdrawal(tx) do
    Pool.parse_tx_from(tx)
    |> Mining.get_miner()
    |> is_nil
    |> Kernel.not
  end

  def get_invalid_deposit_withdrawals(deposit_withdrawals) do
    deposit_withdrawals
    |> Enum.filter(& !validate_deposit_withdrawal_size(&1, Mining.get_miner(&1.address)))
    |> Enum.filter(& !validate_deposit_withdrawal_timelock(&1, Mining.get_miner(&1.address)))
  end

  def validate_deposit_withdrawal_size(deposit_withdrawal, miner) do
    deposit_withdrawal.value <= miner.stake_amount
  end

  def validate_deposit_withdrawal_timelock(deposit_withdrawal, miner) do
    deposit_withdrawal.block_number <= miner.timelock # TODO Add function for getting a transaction's block number.
  end
end
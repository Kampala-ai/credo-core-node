defmodule CredoCoreNode.Mining.DepositWithdrawal do
  alias CredoCoreNode.Mining
  alias CredoCoreNode.Pool

  alias Decimal, as: D

  def validate_deposit_withdrawals(block) do
    block
    |> Pool.list_pending_transactions()
    |> get_deposit_withdrawals()
    |> get_invalid_deposit_withdrawals(block)
    |> Enum.empty?()
  end

  def get_deposit_withdrawals(txs) do
    Enum.filter(txs, &is_deposit_withdrawal(&1))
  end

  def is_deposit_withdrawal(tx) do
    Pool.get_transaction_from_address(tx)
    |> Mining.get_miner()
    |> is_nil
    |> Kernel.not()
  end

  def get_invalid_deposit_withdrawals(deposit_withdrawals, block) do
    deposit_withdrawals
    |> Enum.filter(
      &(!validate_deposit_withdrawal_amount(&1, Mining.get_miner(&1.address), block))
    )
  end

  def validate_deposit_withdrawal_amount(deposit_withdrawal, miner, block) do
    D.cmp(deposit_withdrawal.value, Mining.withdrawable_deposit_value(miner, block)) != :gt
  end
end

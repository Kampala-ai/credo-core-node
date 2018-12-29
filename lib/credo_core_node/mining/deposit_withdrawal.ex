defmodule CredoCoreNode.Mining.DepositWithdrawal do
  alias CredoCoreNode.Mining
  alias CredoCoreNode.Pool

  alias Decimal, as: D

  @behaviour CredoCoreNode.Adapters.DepositWithdrawalAdapter

  def valid_deposit_withdrawals?(block) do
    block
    |> Pool.list_pending_transactions()
    |> get_deposit_withdrawals()
    |> get_invalid_deposit_withdrawals(block)
    |> Enum.empty?()
  end

  defp get_deposit_withdrawals(txs) do
    Enum.filter(txs, &is_deposit_withdrawal?(&1))
  end

  def is_deposit_withdrawal?(tx) do
    tx
    |> get_miner_for_deposit_withdrawal()
    |> is_nil
    |> Kernel.not()
  end

  defp get_miner_for_deposit_withdrawal(deposit_withdrawal) do
    deposit_withdrawal
    |> Pool.get_transaction_from_address()
    |> Mining.get_miner()
  end

  defp get_invalid_deposit_withdrawals(deposit_withdrawals, block) do
    deposit_withdrawals
    |> Enum.filter(&(!valid_deposit_withdrawal?(&1, block)))
  end

  def valid_deposit_withdrawal?(deposit_withdrawal, block),
    do: valid_deposit_withdrawal_amount?(deposit_withdrawal, block)

  defp valid_deposit_withdrawal_amount?(deposit_withdrawal, block) do
    miner = get_miner_for_deposit_withdrawal(deposit_withdrawal)

    D.cmp(deposit_withdrawal.value, Mining.withdrawable_deposit_value(miner, block)) != :gt
  end
end

defmodule CredoCoreNode.Mining.DepositWithdrawal do
  alias CredoCoreNode.Mining
  alias CredoCoreNode.Pool

  @max_timelock_block_height 500_000_000

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
    |> Enum.filter(&(!validate_deposit_withdrawal_size(&1, Mining.get_miner(&1.address))))
    |> Enum.filter(
      &(!validate_deposit_withdrawal_timelock(&1, Mining.get_miner(&1.address), block))
    )
  end

  def validate_deposit_withdrawal_size(deposit_withdrawal, miner) do
    deposit_withdrawal.value <= miner.stake_amount
  end

  def timelock_is_block_height?(timelock),
    do: timelock > 0 && timelock < @max_timelock_block_height

  def withdrawal_is_before_timelock?(block, timelock) do
    if timelock_is_block_height(timelock) do
      block.number >= timelock
    else
      DateTime.compare(DateTime.utc_now(), DateTime.from_unix!(timelock)) != :lt
    end
  end

  def validate_deposit_withdrawal_timelock(deposit_withdrawal, miner, block) do
    withdrawal_is_before_timelock(block, miner.timelock)
  end
end

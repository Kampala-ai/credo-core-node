defmodule CredoCoreNode.Adapters.DepositWithdrawalAdapter do
  alias CredoCoreNode.Blockchain.{Block, Transaction}
  alias CredoCoreNode.Pool.{PendingBlock, PendingTransaction}

  @callback is_deposit_withdrawal?(%PendingTransaction{} | %Transaction{}) :: boolean()

  @callback valid_deposit_withdrawals?(%PendingBlock{} | %Block{}) :: boolean()
  @callback valid_deposit_withdrawal?(
              %PendingTransaction{} | %Transaction{},
              %PendingBlock{} | %Block{}
            ) :: boolean()
end

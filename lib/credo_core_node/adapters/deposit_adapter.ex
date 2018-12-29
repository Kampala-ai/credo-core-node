defmodule CredoCoreNode.Adapters.DepositAdapter do
  alias CredoCoreNode.Blockchain.{Block, Transaction}
  alias CredoCoreNode.Pool.PendingTransaction

  @callback construct_deposit(Decimal.t(), String.t(), String.t(), integer() | nil) ::
              %PendingTransaction{}

  @callback is_deposit(%Transaction{}) :: boolean()
  @callback valid_deposits?(list(%Transaction{})) :: boolean()

  @callback maybe_recognize_deposits(%Block{}) :: list()
  @callback recognize_deposits(list(%Transaction{})) :: list()
end

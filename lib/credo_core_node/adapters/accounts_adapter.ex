defmodule CredoCoreNode.Adapters.AccountsAdapter do
  alias CredoCoreNode.Accounts.Account
  alias CredoCoreNode.Blockchain.Transaction
  alias CredoCoreNode.Mining.Vote
  alias CredoCoreNode.Pool.PendingTransaction

  @callback calculate_public_key(%PendingTransaction{} | %Transaction{} | %Vote{} | String.t()) ::
              {:ok, String.t()}
  @callback payment_address(%Vote{} | String.t()) :: String.t()

  @callback generate_address(String.t() | nil) :: %Account{}
  @callback write_account(map()) :: %Account{}
  @callback save_account(String.t(), String.t() | nil) :: %Account{}

  @callback get_account(String.t()) :: %Account{}
  @callback get_account_balance(String.t()) :: Decimal.t()
  @callback list_accounts() :: list(%Account{})

  @callback delete_account(%Account{}) :: %Account{}
end

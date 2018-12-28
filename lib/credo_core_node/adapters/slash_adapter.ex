defmodule CredoCoreNode.Adapters.SlashAdapter do
  alias CredoCoreNode.Blockchain.Block
  alias CredoCoreNode.Pool.PendingTransaction
  alias CredoCoreNode.Blockchain.Transaction

  @callback generate_slash(String.t(), list(), String.t()) :: %PendingTransaction{}
  @callback construct_miner_slash_tx(String.t(), list(), String.t()) :: %PendingTransaction{}

  @callback is_slash(%PendingTransaction{} | %Transaction{}) :: boolean()
  @callback parse_slash_proof(%PendingTransaction{} | %Transaction{}) :: list()
  @callback valid_slash_proof?(String.t()) :: boolean()

  @callback maybe_apply_slashes(%Block{}) :: list()
  @callback apply_valid_slashes(list(%PendingTransaction{} | %Transaction{})) :: list()
end

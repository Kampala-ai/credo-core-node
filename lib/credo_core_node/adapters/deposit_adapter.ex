defmodule CredoCoreNode.Adapters.DepositAdapter do
  alias CredoCoreNode.Blockchain.Block

  @callback maybe_recognize_deposits(%Block{}) :: list()
end

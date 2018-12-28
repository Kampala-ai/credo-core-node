defmodule CredoCoreNode.Adapters.SlashAdapter do
  alias CredoCoreNode.Blockchain.Block

  @callback maybe_slash_miners(%Block{}) :: list()
end

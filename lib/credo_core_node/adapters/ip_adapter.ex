defmodule CredoCoreNode.Adapters.IpAdapter do
  alias CredoCoreNode.Blockchain.Block

  @callback maybe_update_miner_ips(%Block{}) :: list()
end

defmodule CredoCoreNode.Network.KnownNode do
  defstruct [:url, :last_active_at]

  alias CredoCoreNode.Network.KnownNode

  def from_list(list) do
    %KnownNode{url: Enum.at(list, 0), last_active_at: Enum.at(list, 1)}
  end
end

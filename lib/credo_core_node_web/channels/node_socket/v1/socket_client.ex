Enum.each(0..CredoCoreNode.Network.active_connections_limit(:outgoing) - 1, fn id ->
  defmodule :"Elixir.CredoCoreNodeWeb.NodeSocket.V1.SocketClient#{id}" do
    use PhoenixChannelClient.Socket, otp_app: :credo_core_node
  end
end)

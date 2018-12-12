Enum.each(0..(CredoCoreNode.Network.max_active_connections() - 1), fn id ->
  defmodule :"Elixir.CredoCoreNodeWeb.NodeSocket.V1.SocketClient#{id}" do
    use PhoenixChannelClient.Socket, otp_app: :credo_core_node
  end
end)

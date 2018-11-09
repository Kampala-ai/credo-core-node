Enum.each(0..CredoCoreNode.Network.max_active_connections() - 1, fn id ->
  defmodule :"Elixir.CredoCoreNodeWeb.NodeSocket.V1.EventChannelClient#{id}" do
    use PhoenixChannelClient

    alias CredoCoreNode.Network

    def handle_close(_reason, state) do
      "Elixir.CredoCoreNodeWeb.NodeSocket.V1.EventChannelClient" <> id = Atom.to_string(__MODULE__)

      Network.list_connections()
      |> Enum.find(& &1.socket_client_id == id)
      |> Map.put(:is_active, false)
      |> Network.write_connection()

      {:noreply, state}
    end
  end
end)

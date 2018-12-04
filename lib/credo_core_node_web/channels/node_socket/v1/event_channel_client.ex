Enum.each(0..(CredoCoreNode.Network.active_connections_limit(:outgoing) - 1), fn id ->
  defmodule :"Elixir.CredoCoreNodeWeb.NodeSocket.V1.EventChannelClient#{id}" do
    use PhoenixChannelClient

    import CredoCoreNodeWeb.NodeSocket.V1.EventHandler

    alias CredoCoreNode.Network

    def handle_close(_reason, state) do
      "Elixir.CredoCoreNodeWeb.NodeSocket.V1.EventChannelClient" <> id =
        Atom.to_string(__MODULE__)

      connection =
        Network.list_connections()
        |> Enum.find(&(&1.socket_client_id == id))

      if connection, do: Network.write_connection(%{connection | is_active: false})

      {:noreply, state}
    end
  end
end)

Enum.each(0..(CredoCoreNode.Network.active_connections_limit(:outgoing) - 1), fn id ->
  defmodule :"Elixir.CredoCoreNodeWeb.NodeSocket.V1.EventChannelClient#{id}" do
    require Logger

    use PhoenixChannelClient

    import CredoCoreNodeWeb.NodeSocket.V1.EventHandler

    alias CredoCoreNode.Network
    alias CredoCoreNode.Blockchain

    def handle_in("blocks:body_request", %{"hash" => hash}, state) do
      Logger.info("Received block body request: #{hash}")

      with blk = Blockchain.get_block(hash),
           Blockchain.block_body_fetched?(blk),
           %{body: body} = Blockchain.load_block_body(blk) do
        Logger.info("Sending block body in chunks...")

        body
        |> StreamHelper.stream_binary(4096)
        |> Enum.each(& push("blocks:body_fragment_transfer", %{hash: hash, body_fragment: &1}))

        push("blocks:body_fragment_transfer", %{hash: hash, body_fragment: nil})
      end

      {:noreply, state}
    end

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

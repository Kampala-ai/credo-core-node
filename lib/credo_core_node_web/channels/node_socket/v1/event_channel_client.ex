Enum.each(0..(CredoCoreNode.Network.active_connections_limit(:outgoing) - 1), fn id ->
  defmodule :"Elixir.CredoCoreNodeWeb.NodeSocket.V1.EventChannelClient#{id}" do
    require Logger

    use PhoenixChannelClient

    import CredoCoreNodeWeb.NodeSocket.V1.EventHandler

    alias CredoCoreNode.Network
    alias CredoCoreNode.Blockchain
    alias CredoCoreNode.Pool

    def handle_in("blocks:body_request", %{"hash" => hash}, state) do
      Logger.info("Received block body request: #{hash}")

      with blk = Blockchain.get_block(hash),
           Blockchain.block_body_fetched?(blk),
           %{body: body} = Blockchain.load_block_body(blk) do
        Logger.info("Sending block body in chunks...")

        # HACK: `phoenix_channel_client` doesn't allow to push messages directly from handlers,
        #   using a separate process for that
        module = __MODULE__

        spawn(fn ->
          body
          |> Base.encode64()
          |> StreamHelper.stream_binary(4096)
          |> Enum.each(
            &module.push("blocks:body_fragment_transfer", %{hash: hash, body_fragment: &1})
          )

          module.push("blocks:body_fragment_transfer", %{hash: hash, body_fragment: nil})

          Logger.info("Finished sending block body")
        end)
      end

      {:noreply, state}
    end

    def handle_in("pending_blocks:body_request", %{"hash" => hash}, state) do
      Logger.info("Received pending block body request: #{hash}")

      with blk = Pool.get_pending_block(hash),
           Pool.pending_block_body_fetched?(blk),
           %{body: body} = Pool.load_pending_block_body(blk) do
        Logger.info("Sending pending block body in chunks...")

        # HACK: `phoenix_channel_client` doesn't allow to push messages directly from handlers,
        #   using a separate process for that
        module = __MODULE__

        spawn(fn ->
          body
          |> Base.encode64()
          |> StreamHelper.stream_binary(4096)
          |> Enum.each(
            &module.push("pending_blocks:body_fragment_transfer", %{hash: hash, body_fragment: &1})
          )

          module.push("pending_blocks:body_fragment_transfer", %{hash: hash, body_fragment: nil})

          Logger.info("Finished sending pending block body")
        end)
      end

      {:noreply, state}
    end

    def handle_in("known_nodes:list_request", _params, state) do
      Logger.info("Received known nodes list request")

      known_nodes = Network.list_known_nodes()

      # HACK: `phoenix_channel_client` doesn't allow to push messages directly from handlers,
      #   using a separate process for that
      module = __MODULE__

      spawn(fn ->
        known_nodes
        |> Enum.chunk_every(25)
        |> Enum.each(&module.push("known_nodes:list_fragment_transfer", %{list_fragment: &1}))
      end)

      {:noreply, state}
    end

    def handle_in("phx_close", _params, state), do: handle_close(%{}, state)

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

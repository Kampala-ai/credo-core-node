defmodule CredoCoreNodeWeb.NodeSocket.V1.EventChannel do
  require Logger

  use Phoenix.Channel

  import CredoCoreNodeWeb.NodeSocket.V1.EventHandler

  alias CredoCoreNode.Blockchain

  def join("events:all", _message, socket) do
    {:ok, socket}
  end

  def handle_in(
        "blocks:body_fragment_transfer",
        %{"hash" => hash, "body_fragment" => nil},
        socket
      ) do
    frg = Blockchain.get_block_fragment(hash)

    hash
    |> Blockchain.get_block()
    |> Map.put(:body, frg.body)
    |> Blockchain.write_block()

    Blockchain.delete_block_fragment(frg)

    {:noreply, socket}
  end

  def handle_in(
        "blocks:body_fragment_transfer",
        %{"hash" => hash, "body_fragment" => body_fragment},
        socket
      ) do
    Logger.info("Received block body fragment for: #{hash}")
    frg = Blockchain.get_block_fragment(hash)
    Blockchain.write_block_fragment(%{frg | body: frg.body <> body_fragment})

    {:noreply, socket}
  end
end

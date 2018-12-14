defmodule CredoCoreNodeWeb.NodeSocket.V1.EventChannel do
  require Logger

  use Phoenix.Channel

  import CredoCoreNodeWeb.NodeSocket.V1.EventHandler

  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Blockchain.BlockFragment
  alias CredoCoreNode.Pool
  alias CredoCoreNode.Pool.PendingBlockFragment

  def join("events:all", _message, socket) do
    {:ok, socket}
  end

  def handle_in(
        "blocks:body_fragment_transfer",
        %{"hash" => hash, "body_fragment" => nil},
        socket
      ) do
    Logger.info("Received empty (final) body fragment for block #{hash}")

    frg = Blockchain.get_block_fragment(hash) || %BlockFragment{hash: hash, body: ""}

    case Base.decode64(frg.body) do
      {:ok, ""} ->
        Logger.warn("Empty body for block #{hash} received, ignoring")

      {:ok, body} ->
        Logger.info("Body for block #{hash} decoded, writing block")

        hash
        |> Blockchain.get_block()
        |> Map.put(:body, body)
        |> Blockchain.write_block()

      _ ->
        Logger.warn("Uprocessable body for block #{hash} received, ignoring")
    end

    Blockchain.delete_block_fragment(frg)

    {:noreply, socket}
  end

  def handle_in(
        "blocks:body_fragment_transfer",
        %{"hash" => hash, "body_fragment" => body_fragment},
        socket
      ) do
    Logger.info("Received body fragment for block #{hash}")

    frg = Blockchain.get_block_fragment(hash) || %BlockFragment{hash: hash, body: ""}
    Blockchain.write_block_fragment(%{frg | body: frg.body <> body_fragment})

    {:noreply, socket}
  end

  def handle_in(
        "pending_blocks:body_fragment_transfer",
        %{"hash" => hash, "body_fragment" => nil},
        socket
      ) do
    Logger.info("Received empty (final) body fragment for pending block #{hash}")

    frg = Pool.get_pending_block_fragment(hash) || %PendingBlockFragment{hash: hash, body: ""}

    case Base.decode64(frg.body) do
      {:ok, ""} ->
        Logger.warn("Empty body for pending block #{hash} received, ignoring")

      {:ok, body} ->
        Logger.info("Body for pending_block #{hash} decoded, writing pending block")

        hash
        |> Pool.get_pending_block()
        |> Map.put(:body, body)
        |> Pool.write_pending_block()

      _ ->
        Logger.warn("Uprocessable body for pending block #{hash} received, ignoring")
    end

    Pool.delete_pending_block_fragment(frg)

    {:noreply, socket}
  end

  def handle_in(
        "pending_blocks:body_fragment_transfer",
        %{"hash" => hash, "body_fragment" => body_fragment},
        socket
      ) do
    Logger.info("Received body fragment for pending block #{hash}")

    frg = Pool.get_pending_block_fragment(hash) || %PendingBlockFragment{hash: hash, body: ""}
    Pool.write_pending_block_fragment(%{frg | body: frg.body <> body_fragment})

    {:noreply, socket}
  end
end

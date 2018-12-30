defmodule CredoCoreNodeWeb.NodeSocket.V1.EventChannel do
  require Logger

  use Phoenix.Channel

  import CredoCoreNodeWeb.NodeSocket.V1.EventHandler

  alias CredoCoreNode.{Blockchain, Network, Pool}
  alias CredoCoreNode.Blockchain.{BlockFragment, BlockValidator}
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
        Logger.info("Body for block #{hash} decoded")

        blk = Blockchain.get_block(hash)

        if BlockValidator.valid_block_hash?(blk, hash) &&
             BlockValidator.valid_block_body?(blk, body) do
          if BlockValidator.valid_block?(blk, true) do
            Logger.info("Writing block #{hash}")

            blk
            |> Map.put(:body, body)
            |> Blockchain.write_block()
          else
            Logger.info("Deleting invalid block #{hash}")

            Blockchain.delete_block(blk)
          end
        else
          Logger.info("Invalid block #{hash}, ignoring")
        end

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
        Logger.info("Body for pending_block #{hash} decoded")

        blk = Pool.get_pending_block(hash)

        if BlockValidator.valid_block_hash?(blk, hash) &&
             BlockValidator.valid_block_body?(blk, body) do
          if BlockValidator.valid_block?(blk, true) do
            Logger.info("Writing pending block #{hash}")

            blk
            |> Map.put(:body, body)
            |> Pool.write_pending_block()
          else
            Logger.info("Deleting invalid pending block #{hash}")

            Pool.delete_pending_block(blk)
          end
        else
          Logger.info("Invalid pending_block #{hash}, ignoring")
        end

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

  def handle_in(
        "known_nodes:list_fragment_transfer",
        %{"list_fragment" => list_fragment},
        socket
      ) do
    Logger.info("Received known nodes list fragment")

    Network.merge_known_nodes(list_fragment)

    {:noreply, socket}
  end
end

defmodule CredoCoreNode.Workers.BlockSyncer do
  use GenServer

  require Logger

  import Process, only: [send_after: 3]

  alias CredoCoreNode.Network
  alias CredoCoreNode.Blockchain

  def start_link(interval \\ 10_000) do
    GenServer.start_link(__MODULE__, interval, name: __MODULE__)
  end

  def init(interval) do
    Logger.info("Initializing the block syncer...")

    CredoCoreNode.Network.setup_seed_nodes()

    handle_info(:sync_blocks, interval)

    {:ok, interval}
  end

  def handle_info(:sync_blocks, interval) do
    schedule_sync_blocks(interval)

    sync_headers()
    sync_bodies()

    {:noreply, interval}
  end

  defp sync_headers() do
    Network.list_connections()
    |> Enum.filter(& &1.is_active)
    |> Enum.map(& &1.ip)
    |> Enum.each(&sync_headers/1)
  end

  defp sync_headers(ip) do
    block_numbers =
      Blockchain.list_blocks()
      |> Enum.map(& &1.number)

    last_block_number = Blockchain.last_confirmed_block_number()
    missing_block_numbers = Enum.to_list(0..last_block_number) -- block_numbers

    case List.first(missing_block_numbers) do
      nil -> sync_headers(ip, last_block_number)
      number -> sync_headers(ip, number)
    end
  end

  defp sync_headers(ip, offset) do
    limit = 50
    port = Application.get_env(:credo_core_node, CredoCoreNode.Network)[:node_connection_port]
    url = "#{Network.api_url(ip)}/blocks?offset=#{offset}&limit=#{limit}"
    headers = Network.node_request_headers()

    Logger.info("Syncing block headers from #{ip}:#{port}")

    case :hackney.request(:get, url, headers, "", [:with_body, pool: false]) do
      {:ok, 200, _headers, body} ->
        blocks = Poison.decode!(body)["data"]

        blocks
        |> Enum.each(fn block ->
          unless Blockchain.get_block(block["hash"]) do
            Blockchain.write_block(%{
              hash: block["hash"],
              prev_hash: block["prev_hash"],
              number: block["number"],
              state_root: block["state_root"],
              receipt_root: block["receipt_root"],
              tx_root: block["tx_root"]
            })
          end
        end)

        if length(blocks) == limit, do: sync_headers(ip, offset + limit)

      _ ->
        Logger.info("No response or incorrect response")
    end
  end

  defp sync_bodies() do
    active_connections =
      Network.list_connections()
      |> Enum.filter(& &1.is_active)

    case active_connections do
      [] ->
        :ok

      connections ->
        ips = Enum.reduce(connections, & &1.ip)

        Blockchain.list_blocks()
        |> Enum.filter(&(!Blockchain.block_body_fetched?(&1)))
        |> Enum.each(&Blockchain.fetch_block_body(&1, Enum.random(ips)))
    end
  end

  defp schedule_sync_blocks(interval) do
    send_after(self(), :sync_blocks, interval)
  end
end

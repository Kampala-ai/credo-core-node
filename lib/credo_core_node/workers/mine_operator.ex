defmodule CredoCoreNode.Workers.MineOperator do
  use GenServer

  require Logger

  import Process, only: [send_after: 3]

  alias CredoCoreNode.{Blockchain, Mining}

  @default_interval 60_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, @default_interval, name: __MODULE__)
  end

  def init(interval) do
    Logger.info("Initializing the mine operator...")

    schedule_mine_block(interval)

    {:ok, interval}
  end

  def handle_info(:mine_block, interval) do
    case Mining.is_miner?() do
      true ->
        Blockchain.last_block()
        |> Mining.start_mining()

        schedule_mine_block(2000)

      false ->
        schedule_mine_block(interval)
    end

    {:noreply, interval}
  end

  defp schedule_mine_block(interval) do
    send_after(self(), :mine_block, interval)
  end
end

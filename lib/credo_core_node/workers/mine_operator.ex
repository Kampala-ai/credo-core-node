defmodule CredoCoreNode.Workers.MineOperator do
  use GenServer

  require Logger

  import Process, only: [send_after: 3]

  alias CredoCoreNode.{Blockchain, Mining}

  @default_interval 60_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    Logger.info("Initializing the mine operator...")

    state = %{interval: Keyword.get(opts, :interval, @default_interval)}

    schedule_mine_block(state.interval)

    {:ok, state}
  end

  def handle_info(:mine_block, state) do
    case Mining.is_miner?() do
      true ->
        Blockchain.last_block()
        |> Mining.start_mining()

        schedule_mine_block(2000)

      false ->
        schedule_mine_block(state.interval)
    end

    {:noreply, state}
  end

  defp schedule_mine_block(interval) do
    send_after(self(), :mine_block, interval)
  end
end

defmodule CredoCoreNode.Workers.IpManagerTest do
  use CredoCoreNodeWeb.DataCase, async: false

  import Mox

  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.BlockchainMock
  alias CredoCoreNode.DepositMock
  alias CredoCoreNode.Workers.Ip

  setup :set_mox_from_context
  setup :verify_on_exit!

  describe "ip manager" do
    @describetag table_name: :miners

    test "lists processable blocks" do
      BlockchainMock |> expect(:list_processable_blocks, fn _ -> [] end)
      BlockchainMock |> expect(:last_block, fn -> Blockchain.last_block() end)
      BlockchainMock |> expect(:last_processed_block, fn _ -> Blockchain.last_block() end)

      assert {:ok, pid} = Ip.start_link(interval: 10)

      :timer.sleep(15)

      assert :pong = GenServer.call(pid, :ping)
    end
  end
end

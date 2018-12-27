defmodule CredoCoreNode.MinerTest do
  use CredoCoreNodeWeb.DataCase

  describe "table" do
    @describetag table_name: :miners

    test "has expected fields" do
      assert CredoCoreNode.Mining.Miner.fields == [:address, :ip, :stake_amount, :participation_rate, :inserted_at, :is_self]
    end

  end

end
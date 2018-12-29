defmodule CredoCoreNode.VoteTest do
  use CredoCoreNodeWeb.DataCase

  describe "table" do
    @describetag table_name: :votes

    test "has expected fields" do
      assert CredoCoreNode.Mining.Vote.fields() == [
               :hash,
               :miner_address,
               :block_number,
               :block_hash,
               :voting_round,
               :v,
               :r,
               :s
             ]
    end
  end
end

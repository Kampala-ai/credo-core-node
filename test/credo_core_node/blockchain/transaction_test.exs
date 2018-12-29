defmodule CredoCoreNode.TransactionTest do
  use CredoCoreNodeWeb.DataCase

  describe "table" do
    @describetag table_name: :transactions

    test "has expected fields" do
      assert CredoCoreNode.Blockchain.Transaction.fields() == [
               :hash,
               :nonce,
               :to,
               :value,
               :fee,
               :data,
               :v,
               :r,
               :s
             ]
    end
  end
end

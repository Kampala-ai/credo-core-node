defmodule CredoCoreNode.PendingTransactionTest do
  use CredoCoreNodeWeb.DataCase

  describe "table" do
    @describetag table_name: :pending_transactions

    test "has expected fields" do
      assert CredoCoreNode.Pool.PendingTransaction.fields == [:hash, :nonce, :to, :value, :fee, :data, :v, :r, :s]
    end

  end

end
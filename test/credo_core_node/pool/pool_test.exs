defmodule CredoCoreNode.PoolTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.Pool

  describe "pending_transactions" do
    @describetag table_name: :pending_transactions
    @private_key :crypto.strong_rand_bytes(32)
    @attrs [nonce: 0, to: "abc", value: 1, fee: 1, data: ""]

    def pending_transaction_fixture(private_key \\ @private_key, attrs \\ @attrs) do
      {:ok, pending_transaction} =
        private_key
        |> Pool.generate_pending_transaction(attrs)
        |> elem(1)
        |> Pool.write_pending_transaction()

      pending_transaction
    end

    test "list_pending_transactions/0 returns all pending_transactions" do
      pending_transaction = pending_transaction_fixture()
      assert Pool.list_pending_transactions() == [pending_transaction]
    end

    test "get_pending_transaction!/1 returns the pending_transaction with given hash" do
      pending_transaction = pending_transaction_fixture()
      assert Pool.get_pending_transaction(pending_transaction.hash) == pending_transaction
    end

    test "write_pending_transaction/1 with valid data creates a pending_transaction" do
      assert {:ok, pending_transaction} =
               @private_key
               |> Pool.generate_pending_transaction(@attrs)
               |> elem(1)
               |> Pool.write_pending_transaction()

      assert pending_transaction.nonce == @attrs[:nonce]
      assert pending_transaction.to == @attrs[:to]
      assert pending_transaction.value == @attrs[:value]
      assert pending_transaction.fee == @attrs[:fee]
      assert pending_transaction.data == @attrs[:data]
    end

    test "delete_pending_transaction/1 deletes the pending_transaction" do
      pending_transaction = pending_transaction_fixture()
      assert {:ok, pending_transaction} = Pool.delete_pending_transaction(pending_transaction)
      assert Pool.get_pending_transaction(pending_transaction.hash) == nil
    end
  end
end

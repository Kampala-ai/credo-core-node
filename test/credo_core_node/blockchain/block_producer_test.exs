defmodule CredoCoreNode.BlockProducerTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.Accounts
  alias CredoCoreNode.Pool
  alias CredoCoreNode.Mining
  alias CredoCoreNode.Blockchain.BlockProducer

  alias Decimal, as: D

  describe "validly constructed block" do
    @describetag table_name: :pending_blocks

    def pending_transaction_fixture do
      %CredoCoreNode.Pool.PendingTransaction{
        data: "",
        fee: Decimal.new(1.100000000000000000),
        hash: "34F97321DDC0E56E67CC0AECE02053E64393390730AFDB6F63FB546CB7FA9B46",
        nonce: 0,
        r: "8DBF9628AB59AB7E28418B3D58EE696B744624041BF955075FDD3A2653173905",
        s: "7A4A73877604F44BC673D46CEF6E267283215FCF6CE7AF82C18BFEEBD8053468",
        to: "AF24738B406DB6387D05EB7CE1E90D420B25798F",
        v: 0,
        value: Decimal.new(1_000_000)
      }
      |> CredoCoreNode.Pool.write_pending_transaction()
      |> elem(1)
    end

    def miner_fixture do
      {:ok, account} = Accounts.generate_address("miner")

      Mining.write_miner(%{
        address: account.address,
        ip: "1.1.1.1",
        stake_amount: Decimal.new(1_000),
        participation_rate: 1.0,
        inserted_at: DateTime.utc_now(),
        is_self: true
      })
    end

    def tear_down_pending_transactions do
      Pool.list_pending_transactions()
      |> Enum.each(&Pool.delete_pending_transaction(&1))
    end

    def tear_down_miners do
      Mining.list_miners()
      |> Enum.each(&Mining.delete_miner(&1))
    end

    test "returns error with no_pending_txs when there are no pending txs" do
      tear_down_pending_transactions()

      assert {:error, :no_pending_txs} == BlockProducer.produce_block()
    end

    test "returns a block when there are pending txs" do
      pending_transaction_fixture()

      miner_fixture()

      assert {:ok, _block} = BlockProducer.produce_block()

      tear_down_miners()
    end
  end
end

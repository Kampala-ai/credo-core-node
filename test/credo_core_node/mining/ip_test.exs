defmodule CredoCoreNode.IpTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.{Accounts, Mining, Network}
  alias CredoCoreNode.Mining.Ip

  alias Decimal, as: D

  describe "detecting an ip change" do
    @describetag table_name: :miners

    def miner_fixture(ip) do
      Mining.write_miner(%{
        address: "5EB73D015565D56DB1398B85F17C978B493C0B73",
        ip: ip,
        stake_amount: D.new(1_000),
        participation_rate: 1.0,
        inserted_at: DateTime.utc_now(),
        is_self: true
      })
    end

    test "returns false when the miner's ip hasn't changed" do
      ip = Network.get_current_ip()

      miner_fixture(ip)

      refute Ip.miner_ip_changed?
    end

    test "returns true when the miner's ip has changed" do
      miner_fixture("1.2.3.4")

      assert Ip.miner_ip_changed?
    end
  end
end
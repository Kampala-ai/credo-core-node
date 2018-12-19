defmodule CredoCoreNode.MiningTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.Mining

  alias Decimal, as: D

  describe "deposits" do
    @describetag table_name: :deposits
    @attrs [
      tx_hash: "F2039CE37BDAAAD848BC8BF1B85560C7F05D7BD90DA89A90A61DF1AD001235BD",
      miner_address: "A9A2B9A1EBDDE9EEB5EF733E47FC137D7EB95340",
      amount: D.new(100),
      timelock: 25_000
    ]

    def deposit_fixture(attrs \\ @attrs) do
      {:ok, deposit} =
        attrs
        |> Mining.write_deposit()

      deposit
    end

    test "list_deposits/0 returns all deposits" do
      deposit = deposit_fixture()
      assert Mining.list_deposits() == [deposit]
    end

    test "get_deposit!/1 returns the deposit with given id" do
      deposit = deposit_fixture()
      assert Mining.get_deposit(deposit.tx_hash) == deposit
    end

    test "create_deposit/1 with valid data creates a deposit" do
      assert {:ok, deposit} = Mining.write_deposit(@attrs)
      assert deposit.tx_hash == @attrs[:tx_hash]
    end

    test "delete_deposit/1 deletes the deposit" do
      deposit = deposit_fixture()
      assert {:ok, deposit} = Mining.delete_deposit(deposit)
      assert Mining.get_deposit(deposit.tx_hash) == nil
    end
  end

  describe "miners" do
    @describetag table_name: :miners
    @attrs [
      address: "A9A2B9A1EBDDE9EEB5EF733E47FC137D7EB95340",
      inserted_at: DateTime.utc_now(),
      ip: "10.0.1.4",
      is_self: true,
      participation_rate: 0.729999999999964,
      stake_amount: D.new(10004)
    ]

    def miner_fixture(attrs \\ @attrs) do
      {:ok, miner} =
        attrs
        |> Mining.write_miner()

      miner
    end

    test "list_miners/0 returns all miners" do
      miner = miner_fixture()
      assert Mining.list_miners() == [miner]
    end

    test "get_miner!/1 returns the miner with given id" do
      miner = miner_fixture()
      assert Mining.get_miner(miner.address) == miner
    end

    test "create_miner/1 with valid data creates a miner" do
      assert {:ok, miner} = Mining.write_miner(@attrs)
      assert miner.address == @attrs[:address]
    end

    test "delete_miner/1 deletes the miner" do
      miner = miner_fixture()
      assert {:ok, miner} = Mining.delete_miner(miner)
      assert Mining.get_miner(miner.address) == nil
    end
  end

  describe "slashes" do
    @describetag table_name: :slashes
    @attrs [
      tx_hash: "E088372C04686D74B851F6D8D12F926569C4DB477E968E2FB84BB74FADBCA28E",
      target_miner_address: "A9A2B9A1EBDDE9EEB5EF733E47FC137D7EB95340",
      infraction_block_number: 51
    ]

    def slash_fixture(attrs \\ @attrs) do
      {:ok, slash} =
        attrs
        |> Mining.write_slash()

      slash
    end

    test "list_slashes/0 returns all slashes" do
      slash = slash_fixture()
      assert Mining.list_slashes() == [slash]
    end

    test "get_slash!/1 returns the slash with given id" do
      slash = slash_fixture()
      assert Mining.get_slash(slash.tx_hash) == slash
    end

    test "create_slash/1 with valid data creates a slash" do
      assert {:ok, slash} = Mining.write_slash(@attrs)
      assert slash.tx_hash == @attrs[:tx_hash]
    end

    test "delete_slash/1 deletes the slash" do
      slash = slash_fixture()
      assert {:ok, slash} = Mining.delete_slash(slash)
      assert Mining.get_slash(slash.tx_hash) == nil
    end
  end

  describe "votes" do
    @describetag table_name: :votes
    @attrs [
      block_hash: "3DBAE5255E9172A5B8FD0ACE8AEC70D9F378AA85095B8F6959A92941BDA0EFBB",
      block_number: 42,
      hash: "C28E460947E9F14426E05648838ABE34B75288C720B72C2611FA52513D2E7B99",
      miner_address: "A9A2B9A1EBDDE9EEB5EF733E47FC137D7EB95340",
      r: "D30EE21F929E564A6A675BC40F29D22B54C1C1FAC5C001702B34D077D4C897A7",
      s: "4ACBEAA13DEE5CE3E34C4789FC58531C50D24BA9CD4B9B7B9DB14695E3889390",
      v: 1,
      voting_round: 52
    ]

    def vote_fixture(attrs \\ @attrs) do
      {:ok, vote} =
        attrs
        |> Mining.write_vote()

      vote
    end

    test "list_votes/0 returns all votes" do
      vote = vote_fixture()
      assert Mining.list_votes() == [vote]
    end

    test "get_vote!/1 returns the vote with given id" do
      vote = vote_fixture()
      assert Mining.get_vote(vote.hash) == vote
    end

    test "create_vote/1 with valid data creates a vote" do
      assert {:ok, vote} = Mining.write_vote(@attrs)
      assert vote.hash == @attrs[:hash]
    end

    test "delete_vote/1 deletes the vote" do
      vote = vote_fixture()
      assert {:ok, vote} = Mining.delete_vote(vote)
      assert Mining.get_vote(vote.hash) == nil
    end
  end

  describe "becoming a miner" do
    @describetag table_name: :miners

    def my_miner_fixture do
      Mining.write_miner(%{
        address: "A9A2B9A1EBDDE9EEB5EF733E47FC137D7EB95340",
        ip: "1.1.1.1",
        stake_amount: D.new(1_000),
        participation_rate: 1.0,
        inserted_at: DateTime.utc_now(),
        is_self: true
      })
    end

    test "returns nil if the node already is a miner" do
      my_miner_fixture()

      private_key = :crypto.strong_rand_bytes(32)
      amount = D.new(10_0000)

      assert is_nil(
               Mining.become_miner(
                 amount,
                 private_key,
                 "2BB1D6F107F7A3D5AD92AD2CE984483A34E6381E"
               )
             )
    end

    test "constructs a transaction if the node is not a miner" do
      private_key = :crypto.strong_rand_bytes(32)
      amount = D.new(10_0000)

      refute is_nil(
               Mining.become_miner(
                 amount,
                 private_key,
                 "2BB1D6F107F7A3D5AD92AD2CE984483A34E6381E"
               )
             )
    end
  end

  describe "deleting a miner for an insufficient stake" do
    @describetag table_name: :miners
    @attrs [
      address: "A9A2B9A1EBDDE9EEB5EF733E47FC137D7EB95340",
      inserted_at: DateTime.utc_now(),
      ip: "10.0.1.4",
      is_self: true,
      participation_rate: 0.729999999999964
    ]

    def miner_fixture(attrs, stake_amount) do
      {:ok, miner} =
        attrs ++ [stake_amount: stake_amount]
        |> Mining.write_miner()

      miner
    end

    test "deletes a miner when the stake is insufficient" do
      miner = miner_fixture(@attrs, D.new(9_000))

      Mining.delete_miner_for_insufficient_stake(miner)

      assert is_nil(Mining.get_miner(miner.address))
    end

    test "does not delete a miner when the stake is sufficient" do
      miner = miner_fixture(@attrs, D.new(10_500))

      Mining.delete_miner_for_insufficient_stake(miner)

      refute is_nil(Mining.get_miner(miner.address))
    end
  end

  describe "interpreting timelocks" do
    @describetag table_name: :miners

    test "timelock values below a threshold are interpreted as block numbers" do
      assert Mining.timelock_is_block_height?(100_000)
      assert Mining.timelock_is_block_height?(490_000_000)
    end

    test "timelock values below a threshold are interpreted as unix timestamps" do
      refute Mining.timelock_is_block_height?(510_000_000)
    end
  end
end

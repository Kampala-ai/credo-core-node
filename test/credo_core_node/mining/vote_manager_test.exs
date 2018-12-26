defmodule CredoCoreNode.VoteManagerTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.Accounts
  alias CredoCoreNode.Mining
  alias CredoCoreNode.Mining.{Vote, VoteManager}
  alias CredoCoreNode.Pool

  alias Decimal, as: D

  describe "counting votes" do
    @describetag table_name: :votes

    def miner_fixture(stake_amount, inserted_at \\ DateTime.utc_now(), is_self \\ false) do
      {:ok, account} = Accounts.generate_address("miner")

      Mining.write_miner(%{
        address: account.address,
        ip: "1.1.1.1",
        stake_amount: D.new(stake_amount),
        participation_rate: 1.0,
        inserted_at: inserted_at,
        is_self: is_self
      })
      |> elem(1)
    end

    def vote_fixture(miner, block_hash) do
      %Vote{
        miner_address: miner.address,
        block_number: 1,
        block_hash: block_hash,
        voting_round: 0
      }
      |> VoteManager.sign_vote()
    end

    def pending_block_fixture do
      private_key = :crypto.strong_rand_bytes(32)
      attrs = [nonce: 0, to: "ABC", value: D.new(1), fee: D.new(1), data: ""]

      {:ok, pending_transaction} =
        private_key
        |> Pool.generate_pending_transaction(attrs)
        |> elem(1)
        |> Pool.write_pending_transaction()

      {:ok, pending_block} =
        [pending_transaction]
        |> Pool.generate_pending_block()
        |> elem(1)
        |> Pool.write_pending_block()

      pending_block
    end

    def tear_down_miners do
      Mining.list_miners()
      |> Enum.each(&Mining.delete_miner(&1))
    end

    test "sums up votes correctly" do
      minerA = miner_fixture(10000)
      minerB = miner_fixture(1000)
      minerC = miner_fixture(5000)

      blockHashA = "B73BC51DF28E5DD2493DED1A2DF22A714217159ABD059E0FF802E46DE16E2C7B"
      blockHashB = "EBA692825740B1C2FE4F0AC106B32B6F41A2DA6B638CB7302C2C98F9B91C96A6"

      votes = [
        vote_fixture(minerA, blockHashA),
        vote_fixture(minerB, blockHashA),
        vote_fixture(minerC, blockHashB)
      ]

      results = VoteManager.count_votes(votes)

      assert D.cmp(Enum.find(results, &(&1[:hash] == blockHashA))[:count], D.new(11000)) == :eq
      assert D.cmp(Enum.find(results, &(&1[:hash] == blockHashB))[:count], D.new(5000)) == :eq
    end
  end

  describe "determining a winner" do
    @describetag table_name: :votes

    test "gets the correct winner" do
      pending_block = pending_block_fixture()

      tear_down_miners()

      minerA = miner_fixture(5000)
      minerB = miner_fixture(5500)
      minerC = miner_fixture(1000)

      blockHashA = pending_block.hash
      blockHashB = "EBA692825740B1C2FE4F0AC106B32B6F41A2DA6B638CB7302C2C98F9B91C96A6"

      votes = [
        vote_fixture(minerA, blockHashA),
        vote_fixture(minerB, blockHashA),
        vote_fixture(minerC, blockHashB)
      ]

      winner =
        votes
        |> VoteManager.count_votes()
        |> VoteManager.get_winner(votes)

      assert winner == pending_block
    end

    test "returns nil when no block hash has a supermajority vote votes" do
      pending_block = pending_block_fixture()

      tear_down_miners()

      minerA = miner_fixture(2500)
      minerB = miner_fixture(2500)
      minerC = miner_fixture(5500)

      blockHashA = pending_block.hash
      blockHashB = "EBA692825740B1C2FE4F0AC106B32B6F41A2DA6B638CB7302C2C98F9B91C96A6"

      votes = [
        vote_fixture(minerA, blockHashA),
        vote_fixture(minerB, blockHashA),
        vote_fixture(minerC, blockHashB)
      ]

      winner =
        votes
        |> VoteManager.count_votes()
        |> VoteManager.get_winner(votes)

      assert is_nil(winner)
    end
  end

  describe "validating votes" do
    @describetag table_name: :votes

    test "deems votes with the wrong signature to be invalid" do
      miner = miner_fixture(5000)

      vote = %{
        vote_fixture(miner, "EBA692825740B1C2FE4F0AC106B32B6F41A2DA6B638CB7302C2C98F9B91C96A6")
        | miner_address: "A9A2B9A1EBDDE9EEB5EF733E47FC137D7EB95340"
      }

      refute VoteManager.is_valid_vote(vote)
    end

    test "deems votes from a new miner as invalid" do
      miner = miner_fixture(5000)

      vote =
        vote_fixture(miner, "EBA692825740B1C2FE4F0AC106B32B6F41A2DA6B638CB7302C2C98F9B91C96A6")

      refute VoteManager.is_valid_vote(vote)
    end

    test "deems votes with a valid signature from a miner that passed the warm up period as valid" do
      miner = miner_fixture(5000, DateTime.from_unix!(1_464_096_368))

      vote =
        vote_fixture(miner, "EBA692825740B1C2FE4F0AC106B32B6F41A2DA6B638CB7302C2C98F9B91C96A6")

      assert VoteManager.is_valid_vote(vote)
    end
  end

  describe "checking whether a node's miner already voted" do
    @describetag table_name: :votes
    @voting_round 0

    test "returns true if a node's miner has voted" do
      block = pending_block_fixture()

      miner_fixture(10_000, DateTime.utc_now(), true)
      |> vote_fixture(block.hash)
      |> Mining.write_vote()

      assert VoteManager.already_voted?(block, @voting_round)
    end

    test "returns false if a node's miner has voted" do
      miner = miner_fixture(10_000, DateTime.utc_now(), true)
      block = pending_block_fixture()

      refute VoteManager.already_voted?(block, @voting_round)
    end
  end

  describe "checking whether another miner has voted" do
    @describetag table_name: :votes
    @voting_round 0

    test "returns true if a specified miner has voted" do
      miner = miner_fixture(10_000, DateTime.utc_now(), false)
      block = pending_block_fixture()

      miner
      |> vote_fixture(block.hash)
      |> Mining.write_vote()

      votes = Mining.list_votes_for_round(block, @voting_round)

      assert VoteManager.miner_voted?(votes, miner)
    end

    test "returns false if a specified miner has voted" do
      miner = miner_fixture(10_000, DateTime.utc_now(), false)
      block = pending_block_fixture()

      votes = Mining.list_votes_for_round(block, @voting_round)

      refute VoteManager.miner_voted?(votes, miner)
    end
  end
end

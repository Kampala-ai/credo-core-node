defmodule CredoCoreNode.SlashTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.Accounts
  alias CredoCoreNode.Mining
  alias CredoCoreNode.Mining.{Slash, Vote, VoteManager}

  alias Decimal, as: D

  describe "slashes" do
    @describetag table_name: :slashes

    def miner_fixture do
      {:ok, account} = Accounts.generate_address("miner")

      Mining.write_miner(%{
        address: account.address,
        ip: "1.1.1.1",
        stake_amount: Decimal.new(1_000),
        participation_rate: 1.0,
        inserted_at: DateTime.utc_now(),
        is_self: false
      })
      |> elem(1)
    end

    def byzantine_behavior_proof_fixture(miner, vote_round) do
      [
        %Vote{
          miner_address: miner.address,
          block_number: 1,
          block_hash: "B73BC51DF28E5DD2493DED1A2DF22A714217159ABD059E0FF802E46DE16E2C7B",
          voting_round: vote_round
        }
        |> VoteManager.sign_vote(),
        %Vote{
          miner_address: miner.address,
          block_number: 1,
          block_hash: "A79C83020ED99A47919874034601862306A890B6505E25F9BCB0331FBE688F24",
          voting_round: vote_round
        }
        |> VoteManager.sign_vote()
      ]
    end

    def slash_tx_fixture(miner, vote_round \\ 0) do
      private_key = :crypto.strong_rand_bytes(32)
      byzantine_behavior_proof = byzantine_behavior_proof_fixture(miner, vote_round)
      to = miner.address

      Slash.construct_miner_slash_tx(private_key, byzantine_behavior_proof, to)
    end

    test "constructing a slash transaction creates a valid slash transaction" do
      miner = miner_fixture()
      tx = slash_tx_fixture(miner)

      assert Slash.is_slash(tx)
      assert Slash.slash_proof_is_valid?(Slash.parse_proof(tx))
    end

    test "processing a slash saves a slash a miner's stake" do
      miner = miner_fixture()
      tx = slash_tx_fixture(miner)

      stake_amount_before_slash = miner.stake_amount

      Slash.validate_and_slash_miners([tx])

      slashed_miner = Mining.get_miner(miner.address)

      assert D.cmp(slashed_miner.stake_amount, D.mult(D.new(0.8), stake_amount_before_slash)) == :eq
    end

    test "processing a slash saves the slash transaction" do
      miner = miner_fixture()
      tx = slash_tx_fixture(miner)

      Slash.validate_and_slash_miners([tx])

      assert !is_nil(Mining.get_slash(tx.hash))
    end

    test "ensuring a miner is not slashed twice for a block number" do
      miner = miner_fixture()
      slash = slash_tx_fixture(miner)
      second_slash = slash_tx_fixture(miner, 1)

      stake_amount_before_slash = miner.stake_amount

      Slash.validate_and_slash_miners([slash, second_slash])

      slashed_miner = Mining.get_miner(miner.address)

      assert D.cmp(slashed_miner.stake_amount, D.mult(D.new(0.8), stake_amount_before_slash)) == :eq

      Slash.validate_and_slash_miners([second_slash])

      slashed_miner = Mining.get_miner(miner.address)

      assert D.cmp(slashed_miner.stake_amount, D.mult(D.new(0.8), stake_amount_before_slash)) == :eq
    end
  end
end

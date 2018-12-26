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
        stake_amount: D.new(1_000),
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

    def slash_tx_fixture(miner, vote_round \\ 0, proof \\ nil) do
      private_key = :crypto.strong_rand_bytes(32)
      byzantine_behavior_proof = proof || byzantine_behavior_proof_fixture(miner, vote_round)
      to = miner.address

      Slash.construct_miner_slash_tx(private_key, byzantine_behavior_proof, to)
    end

    test "constructing a slash transaction creates a valid slash transaction" do
      miner = miner_fixture()
      tx = slash_tx_fixture(miner)

      assert Slash.is_slash(tx)
      assert Slash.valid_slash_proof?(Slash.parse_proof(tx))
    end

    test "processing a slash saves a slash a miner's stake" do
      miner = miner_fixture()
      tx = slash_tx_fixture(miner)

      stake_amount_before_slash = miner.stake_amount

      Slash.validate_and_slash_miners([tx])

      slashed_miner = Mining.get_miner(miner.address)

      assert D.cmp(slashed_miner.stake_amount, D.mult(D.new(0.8), stake_amount_before_slash)) ==
               :eq
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

      assert D.cmp(slashed_miner.stake_amount, D.mult(D.new(0.8), stake_amount_before_slash)) ==
               :eq

      Slash.validate_and_slash_miners([second_slash])

      slashed_miner = Mining.get_miner(miner.address)

      assert D.cmp(slashed_miner.stake_amount, D.mult(D.new(0.8), stake_amount_before_slash)) ==
               :eq
    end
  end

  describe "verifying slash proofs" do
    @describetag table_name: :slashes

    test "returns true for a valid slash proof" do
      miner = miner_fixture()
      tx = slash_tx_fixture(miner)

      assert Slash.valid_slash_proof?(Slash.parse_proof(tx))
    end

    test "returns true for a proof with votes specifying different voting rounds" do
      miner = miner_fixture()
      vote_round = 0
      second_vote_round = 1

      different_miner_addresses_proof = [
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
          voting_round: second_vote_round
        }
        |> VoteManager.sign_vote()
      ]

      tx = slash_tx_fixture(miner, vote_round, different_miner_addresses_proof)

      refute Slash.valid_slash_proof?(Slash.parse_proof(tx))
    end

    test "returns false for a proof with a single vote" do
      miner = miner_fixture()
      vote_round = 0

      single_vote_proof = [
        %Vote{
          miner_address: miner.address,
          block_number: 1,
          block_hash: "B73BC51DF28E5DD2493DED1A2DF22A714217159ABD059E0FF802E46DE16E2C7B",
          voting_round: vote_round
        }
        |> VoteManager.sign_vote()
      ]

      tx = slash_tx_fixture(miner, vote_round, single_vote_proof)

      refute Slash.valid_slash_proof?(Slash.parse_proof(tx))
    end

    test "returns false for a proof with votes specifying different block numbers" do
      miner = miner_fixture()
      vote_round = 0

      different_block_numbers_proof = [
        %Vote{
          miner_address: miner.address,
          block_number: 1,
          block_hash: "B73BC51DF28E5DD2493DED1A2DF22A714217159ABD059E0FF802E46DE16E2C7B",
          voting_round: vote_round
        }
        |> VoteManager.sign_vote(),
        %Vote{
          miner_address: miner.address,
          block_number: 2,
          block_hash: "A79C83020ED99A47919874034601862306A890B6505E25F9BCB0331FBE688F24",
          voting_round: vote_round
        }
        |> VoteManager.sign_vote()
      ]

      tx = slash_tx_fixture(miner, vote_round, different_block_numbers_proof)

      refute Slash.valid_slash_proof?(Slash.parse_proof(tx))
    end

    test "returns false for a proof with votes specifying the same block hash" do
      miner = miner_fixture()
      vote_round = 0

      same_block_hash_proof = [
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
          block_hash: "B73BC51DF28E5DD2493DED1A2DF22A714217159ABD059E0FF802E46DE16E2C7B",
          voting_round: vote_round
        }
        |> VoteManager.sign_vote()
      ]

      tx = slash_tx_fixture(miner, vote_round, same_block_hash_proof)

      refute Slash.valid_slash_proof?(Slash.parse_proof(tx))
    end

    test "returns false for a proof with votes specifying different miner addresses" do
      miner = miner_fixture()
      second_miner = miner_fixture()
      vote_round = 0

      different_miner_addresses_proof = [
        %Vote{
          miner_address: miner.address,
          block_number: 1,
          block_hash: "B73BC51DF28E5DD2493DED1A2DF22A714217159ABD059E0FF802E46DE16E2C7B",
          voting_round: vote_round
        }
        |> VoteManager.sign_vote(),
        %Vote{
          miner_address: second_miner.address,
          block_number: 1,
          block_hash: "A79C83020ED99A47919874034601862306A890B6505E25F9BCB0331FBE688F24",
          voting_round: vote_round
        }
        |> VoteManager.sign_vote()
      ]

      tx = slash_tx_fixture(miner, vote_round, different_miner_addresses_proof)

      refute Slash.valid_slash_proof?(Slash.parse_proof(tx))
    end
  end
end

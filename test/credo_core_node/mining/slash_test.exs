defmodule CredoCoreNode.SlashTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.Accounts
  alias CredoCoreNode.Mining
  alias CredoCoreNode.Mining.{Slash, Vote, VoteManager}

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

    def byzantine_behavior_proof_fixture(miner) do
      [
        %Vote{
          miner_address: miner.address,
          block_number: 1,
          block_hash: "B73BC51DF28E5DD2493DED1A2DF22A714217159ABD059E0FF802E46DE16E2C7B",
          voting_round: 0
        }
        |> VoteManager.sign_vote(),
        %Vote{
          miner_address: miner.address,
          block_number: 1,
          block_hash: "A79C83020ED99A47919874034601862306A890B6505E25F9BCB0331FBE688F24",
          voting_round: 0
        }
        |> VoteManager.sign_vote()
      ]
    end

    test "constructing a slash transaction " do
      private_key = :crypto.strong_rand_bytes(32)
      miner = miner_fixture()
      byzantine_behavior_proof = byzantine_behavior_proof_fixture(miner)
      to = miner.address

      tx = Slash.construct_miner_slash_tx(private_key, byzantine_behavior_proof, to)

      assert Slash.is_slash(tx)
      assert Slash.slash_proof_is_valid?(Slash.parse_proof(tx))
    end
  end
end

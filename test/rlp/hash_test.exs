defmodule CredoCoreNode.RLPHashTest do
  use CredoCoreNodeWeb.DataCase
  alias CredoCoreNode.{Accounts, Blockchain, Pool}
  alias CredoCoreNode.Mining.{Vote, VoteManager}

  alias Decimal, as: D

  describe "hashing data structures" do
    @describetag table_name: :transactions
    @private_key <<77, 162, 207, 193, 149, 91, 138, 64, 173, 125, 99, 195, 158, 11, 37, 172, 190,
                   200, 51, 185, 156, 82, 37, 26, 46, 170, 9, 241, 44, 128, 230, 9>>
    @attrs [nonce: 0, to: "ABC", value: D.new(1), fee: D.new(1), data: ""]

    def block_fixture(private_key \\ @private_key, attrs \\ @attrs) do
      pending_transaction = pending_transaction_fixture()

      {:ok, block} =
        [pending_transaction]
        |> Pool.generate_pending_block()
        |> elem(1)
        |> Blockchain.write_block()

      block
    end

    def pending_block_fixture(private_key \\ @private_key, attrs \\ @attrs) do
      pending_transaction = pending_transaction_fixture()

      {:ok, pending_block} =
        [pending_transaction]
        |> Pool.generate_pending_block()
        |> elem(1)
        |> Pool.write_pending_block()

      pending_block
    end

    def pending_transaction_fixture(private_key \\ @private_key, attrs \\ @attrs) do
      {:ok, pending_transaction} =
        private_key
        |> Pool.generate_pending_transaction(attrs)
        |> elem(1)
        |> Pool.write_pending_transaction()

      pending_transaction
    end

    def transaction_fixture(private_key \\ @private_key, attrs \\ @attrs) do
      {:ok, transaction} =
        private_key
        |> Pool.generate_pending_transaction(attrs)
        |> elem(1)
        |> Blockchain.write_transaction()

      transaction
    end

    def vote_fixture() do
      %Vote{
        miner_address: "C3F9BFC7A3000903A6FD0B27CD01B59ED4AB7F7E",
        block_number: 1,
        block_hash: "02057C51C1DDD6E5BCE58BF3AF7946FDF2925B79E051853B3DE0E7C2B723A426",
        voting_round: 0
      }
      |> VoteManager.sign_vote()
    end

    def tear_down_blocks() do
      Enum.each(Blockchain.list_blocks(), fn block ->
        unless block.number == 0 do
          Blockchain.delete_block(block)
        end
      end)
    end

    def tear_down_pending_blocks() do
      Enum.each(Pool.list_pending_blocks(), fn pending_block ->
        unless pending_block.number == 0 do
          Pool.delete_pending_block(pending_block)
        end
      end)
    end

    test "hashing blocks renders correct hash" do
      Blockchain.load_genesis_block()
      tear_down_blocks()

      block = block_fixture()

      assert RLP.Hash.hex(block) ==
               "A0496CD2988EADC5B4CCE7522CEDE9B062B9EAACA53FC7557F2051BE7B181CFC"
    end

    test "hashing pending blocks renders correct hash" do
      tear_down_blocks()
      Blockchain.load_genesis_block()
      tear_down_pending_blocks()

      pending_block = pending_block_fixture()

      assert RLP.Hash.hex(pending_block) ==
               "A0496CD2988EADC5B4CCE7522CEDE9B062B9EAACA53FC7557F2051BE7B181CFC"
    end

    test "hashing pending transactions renders correct hash" do
      tx = pending_transaction_fixture()

      assert RLP.Hash.hex(tx) ==
               "F46FE74EE5DCE82235DEF58A9BB44E2257D9A1C56F4B06A2F9F5D1CBFF5E9DE5"
    end

    test "hashing transactions renders correct hash" do
      tx = transaction_fixture()

      assert RLP.Hash.hex(tx) ==
               "F46FE74EE5DCE82235DEF58A9BB44E2257D9A1C56F4B06A2F9F5D1CBFF5E9DE5"
    end

    test "hashing votes renders correct hash" do
      Accounts.save_account("8B4460A032C2287DF59A2D58AC36BD0EB7D6182827A2E20388DE5040A4C92839")
      vote = vote_fixture()

      assert RLP.Hash.hex(vote) ==
               "8B5FB92862BB37288098C24ED04AD87EA1CA4ADDA14AC1E9353C145F11C043A2"
    end
  end
end

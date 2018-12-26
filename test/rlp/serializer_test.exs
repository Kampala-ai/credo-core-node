defmodule CredoCoreNode.RLPSerializerTest do
  use CredoCoreNodeWeb.DataCase
  alias CredoCoreNode.{Accounts, Blockchain, Pool}
  alias CredoCoreNode.Mining.{Vote, VoteManager}

  alias Decimal, as: D

  describe "encoding data structures using RLP" do
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

    test "encoding blocks using RLP returns the expected encoding" do
      Blockchain.load_genesis_block()
      tear_down_blocks()

      block = block_fixture()

      assert ExRLP.encode(block, encoding: :hex) ==
               "f887b84041353036313739373045453344453433424137423639463042333531453632414635323642303039374533454630384341334232443030374644453431354441018080b84044414237423339424146454335423135454132313642453036373343414541303344383242454338324630384438454244373536463431433836394532374632"
    end

    test "encoding pending blocks returns the expected encoding RLP" do
      tear_down_blocks()
      Blockchain.load_genesis_block()
      tear_down_pending_blocks()

      pending_block = pending_block_fixture()

      assert ExRLP.encode(pending_block, encoding: :hex) ==
               "f887b84041353036313739373045453344453433424137423639463042333531453632414635323642303039374533454630384341334232443030374644453431354441018080b84044414237423339424146454335423135454132313642453036373343414541303344383242454338324630384438454244373536463431433836394532374632"
    end

    test "encoding pending transactions returns the expected encoding RLP" do
      tx = pending_transaction_fixture()

      assert ExRLP.encode(tx, encoding: :hex) ==
               "f89d8083414243880de0b6b3a7640000880de0b6b3a76400008080b84033324233343435443830313831383243433435343545444532463130463236443732313732453246314339394138393430354541434333383344363634393037b84037394646343635323946394142433145364130303538413632324334393136343637383030464141303035373439374343383338443834364136384242454137"
    end

    test "encoding transactions using RLP returns the expected encoding" do
      tx = pending_transaction_fixture()

      assert ExRLP.encode(tx, encoding: :hex) ==
               "f89d8083414243880de0b6b3a7640000880de0b6b3a76400008080b84033324233343435443830313831383243433435343545444532463130463236443732313732453246314339394138393430354541434333383344363634393037b84037394646343635323946394142433145364130303538413632324334393136343637383030464141303035373439374343383338443834364136384242454137"
    end

    test "encoding votes using RLP returns the expected encoding" do
      Accounts.save_account("8B4460A032C2287DF59A2D58AC36BD0EB7D6182827A2E20388DE5040A4C92839")
      vote = vote_fixture()

      assert ExRLP.encode(vote, encoding: :hex) ==
               "f8f2a84333463942464337413330303039303341364644304232374344303142353945443441423746374501b840303230353743353143314444443645354243453538424633414637393436464446323932354237394530353138353342334445304537433242373233413432368001b84044343543323046453233344438454338384535343233364235324339363131443636344339434238333734364539324233433430363444463738424334423936b84031433532333932314635384335363037454434334443344337433133344137333346324536363237343131464139383745413631343034463831463539353835"
    end
  end
end

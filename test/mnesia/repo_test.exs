defmodule CredoCoreNode.RepoTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.Accounts.Account
  alias CredoCoreNode.Accounts
  alias Mnesia.Repo

  describe "get record" do
    @describetag table_name: :accounts

    test "returns a record" do
      account =
        Accounts.generate_address()
        |> elem(1)

      assert Repo.get(Account, account.address) == account
    end
  end

  describe "write record" do
    @describetag table_name: :accounts
    @private_key :crypto.strong_rand_bytes(32)

    test "persists a record to the database" do
      address =
        @private_key
        |> Accounts.calculate_public_key()
        |> elem(1)
        |> Accounts.payment_address()

      {:ok, account} =
        Accounts.write_account(%{
          address: address,
          private_key: @private_key,
          public_key: nil,
          label: nil
        })

      assert Repo.get(Account, account.address) == account
    end
  end

  describe "delete record" do
    @describetag table_name: :accounts

    test "returns nil after the record is deleted" do
      account =
        Accounts.generate_address()
        |> elem(1)

      Repo.delete(account)

      assert Repo.get(Account, account.address) == nil
    end
  end

  describe "list records" do
    @describetag table_name: :accounts

    test "returns a record" do
      tear_down_accounts()

      account =
        Accounts.generate_address()
        |> elem(1)

      account_two =
        Accounts.generate_address()
        |> elem(1)

      list = Repo.list(Account)

      assert Enum.member?(list, account)
      assert Enum.member?(list, account_two)
    end
  end

  describe "limit list queries" do
    @describetag table_name: :accounts

    def tear_down_accounts do
      Enum.each(Accounts.list_accounts(), &Accounts.delete_account(&1))
    end

    def accounts_fixture do
      Accounts.generate_address()
      Accounts.generate_address()
      Accounts.generate_address()
    end

    test "returns full results when no limit is supplied" do
      tear_down_accounts()
      accounts_fixture()

      assert length(Repo.list(Account)) == 3
    end

    test "returns limited results when a limit is supplied" do
      tear_down_accounts()
      accounts_fixture()

      assert length(Repo.list(Account, 0)) == 0
      assert length(Repo.list(Account, 1)) == 1
      assert length(Repo.list(Account, 2)) == 2
    end
  end
end

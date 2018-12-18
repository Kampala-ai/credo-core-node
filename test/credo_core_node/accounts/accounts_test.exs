defmodule CredoCoreNode.AccountsTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.Accounts

  alias Decimal, as: D

  describe "accounts" do
    @describetag table_name: :accounts
    @attrs [
      address: "2BB1D6F107F7A3D5AD92AD2CE984483A34E6381E",
      label: "test",
      private_key:
        <<212, 93, 219, 73, 97, 13, 114, 247, 158, 147, 154, 108, 212, 236, 153, 88, 224, 103,
          199, 247, 31, 161, 202, 234, 145, 129, 200, 212, 43, 119, 137, 198>>,
      public_key:
        <<76, 233, 247, 22, 192, 241, 116, 128, 144, 249, 140, 90, 99, 255, 31, 115, 38, 168, 170,
          246, 250, 193, 120, 95, 102, 253, 190, 120, 36, 184, 183, 98, 109, 130, 111, 194, 130,
          42, 178, 200, 18, 144, 109, 140, 84, 187, 174, 197, 178, 13, 245, 1, 243, 29, 161, 101,
          199, 79, 3, 150, 232, 186, 184, 255>>
    ]

    def account_fixture(attrs \\ @attrs) do
      {:ok, account} =
        attrs
        |> Accounts.write_account()

      account
    end

    test "list_accounts/0 returns all accounts" do
      account = account_fixture()
      assert Accounts.list_accounts() == [account]
    end

    test "get_account!/1 returns the account with given id" do
      account = account_fixture()
      assert Accounts.get_account(account.address) == account
    end

    test "create_account/1 with valid data creates a account" do
      assert {:ok, account} = Accounts.write_account(@attrs)
      assert account.address == @attrs[:address]
    end

    test "delete_account/1 deletes the account" do
      account = account_fixture()
      assert {:ok, account} = Accounts.delete_account(account)
      assert Accounts.get_account(account.address) == nil
    end

    test "get_account_balance/1 gets the correct account balance" do
      assert D.cmp(Accounts.get_account_balance("F7DA6E2803E37C10D591C08EBFE2F8A018352955"), D.new(1_374_719_257.2286)) == :eq
      assert D.cmp(Accounts.get_account_balance("A9A2B9A1EBDDE9EEB5EF733E47FC137D7EB95340"), D.new(10000.0)) == :eq
      assert D.cmp(Accounts.get_account_balance("2BB1D6F107F7A3D5AD92AD2CE984483A34E6381E"), D.new(0.0)) == :eq
    end
  end
end

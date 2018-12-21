defmodule CredoCoreNode.RepoTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.Accounts.Account
  alias CredoCoreNode.Accounts
  alias Mnesia.Repo

  describe "limiting list queries" do
    @describetag table_name: :accounts

    def tear_down_accounts do
      Enum.each(Accounts.list_accounts, &(Accounts.delete_account(&1)))
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
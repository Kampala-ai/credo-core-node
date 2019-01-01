defmodule CredoCoreNodeWeb.ClientApi.V1.AccountView do
  use CredoCoreNodeWeb, :view

  def render("index.json", %{accounts: accounts}) do
    %{data: render_many(accounts, __MODULE__, "show.json")}
  end

  def render("show.json", %{account: account}) do
    %{
      address: account.address,
      balance: account.balance,
      nonce: account.nonce
    }
  end

  def render("create.json", %{account: account}) do
    %{
      address: account.address,
      private_key: Base.encode16(account.private_key),
      public_key: Base.encode16(account.public_key),
      label: account.label
    }
  end
end

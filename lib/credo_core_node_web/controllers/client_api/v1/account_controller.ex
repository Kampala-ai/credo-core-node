defmodule CredoCoreNodeWeb.ClientApi.V1.AccountController do
  use CredoCoreNodeWeb, :controller

  alias CredoCoreNode.Accounts

  def create(conn, params) do
    {:ok, account} = Accounts.generate_address(params["label"])

    conn
    |> put_status(:created)
    |> render("create.json", account: account)
  end

  def show(conn, %{"id" => id}) do
    render(conn, "show.json", account: %{address: id, balance: Accounts.get_account_balance(id)})
  end
end

defmodule CredoCoreNodeWeb.NodeApi.V1.AccountControllerTest do
  use CredoCoreNodeWeb.ConnCase

  alias CredoCoreNode.Accounts

  describe "create" do
    @label Faker.Lorem.Shakespeare.hamlet()

    test "creates an account", %{conn: conn} do
      conn = post(conn, client_api_v1_account_path(conn, :create, %{label: @label}))

      %{"private_key" => private_key, "public_key" => public_key, "address" => address, "label" => label} = json_response(conn, 201)

      decoded_private_key = elem(Base.decode16(private_key), 1)

      assert label == @label
      assert public_key == Base.encode16((p_key = elem(Accounts.calculate_public_key(decoded_private_key), 1)))
      assert address ==  Accounts.payment_address(p_key)
    end
  end
end

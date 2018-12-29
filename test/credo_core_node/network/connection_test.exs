defmodule CredoCoreNode.ConnectionTest do
  use CredoCoreNodeWeb.DataCase

  describe "table" do
    @describetag table_name: :connections

    test "has expected fields" do
      assert CredoCoreNode.Network.Connection.fields() == [
               :ip,
               :is_active,
               :is_outgoing,
               :failed_attempts_count,
               :socket_client_id,
               :session_id,
               :updated_at
             ]
    end
  end
end

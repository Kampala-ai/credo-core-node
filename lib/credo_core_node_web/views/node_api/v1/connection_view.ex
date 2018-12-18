defmodule CredoCoreNodeWeb.NodeApi.V1.ConnectionView do
  use CredoCoreNodeWeb, :view

  def render("index.json", %{connections: connections}) do
    %{data: render_many(connections, __MODULE__, "show.json")}
  end

  def render("show.json", %{connection: connection}) do
    %{session_id: connection.session_id}
  end
end

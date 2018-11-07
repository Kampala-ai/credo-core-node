defmodule CredoCoreNodeWeb.NodeApi.V1.BlockView do
  use CredoCoreNodeWeb, :view

  def render("index.json", %{blocks: blocks}) do
    %{data: render_many(blocks, __MODULE__, "show.json")}
  end

  def render("show.json", %{block: block}) do
    %{
      hash: block.hash,
      prev_hash: block.prev_hash,
      number: block.number,
      state_root: block.state_root,
      receipt_root: block.receipt_root,
      tx_root: block.tx_root
    }
  end
end

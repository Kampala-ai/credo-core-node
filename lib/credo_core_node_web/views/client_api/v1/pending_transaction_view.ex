defmodule CredoCoreNodeWeb.ClientApi.V1.PendingTransactionView do
  use CredoCoreNodeWeb, :view

  def render("index.json", %{pending_transactions: pending_transactions}) do
    %{data: render_many(pending_transactions, __MODULE__, "show.json")}
  end

  def render("show.json", %{pending_transaction: pending_transaction}) do
    %{
      hash: pending_transaction.hash,
      nonce: pending_transaction.nonce,
      to: pending_transaction.to,
      value: pending_transaction.value,
      fee: pending_transaction.fee,
      data: pending_transaction.data,
      v: pending_transaction.v,
      r: pending_transaction.r,
      s: pending_transaction.s
    }
  end
end

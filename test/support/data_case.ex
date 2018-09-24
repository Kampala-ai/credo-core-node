defmodule CredoCoreNodeWeb.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  setup tags do
    table_suffix = Application.get_env(:credo_core_node, Mnesia)[:table_suffix]
    table_name = :"#{tags[:table_name]}_#{table_suffix}"

    on_exit fn ->
      table_name
      |> :mnesia.dirty_all_keys()
      |> Enum.each(&(:mnesia.dirty_delete(table_name, &1)))
    end

    :ok
  end
end

defmodule Mnesia.Repo do
  defp table_suffix(), do: Application.get_env(:credo_core_node, Mnesia)[:table_suffix]

  def setup() do
    :mnesia.create_schema([node()])
    :mnesia.start()

    with {:ok, list} <- :application.get_key(:credo_core_node, :modules) do
      modules =
        list
        |> Enum.filter(
          &(&1 |> Module.split() |> Enum.take(2) |> Enum.join(".") == "Mnesia.Schemas")
        )
        |> Enum.map(
          &(&1
            |> Atom.to_string()
            |> String.replace("Mnesia.Schemas", "CredoCoreNode")
            |> String.to_atom())
        )

      Enum.each(modules, fn module ->
        :mnesia.create_table(:"#{module.table_name()}_#{table_suffix()}",
          attributes: module.fields()
        )
      end)
    end
  end

  @doc """
  Returns the list of records.
  """
  def list(schema) do
    :"#{schema.table_name()}_#{table_suffix()}"
    |> :mnesia.dirty_all_keys()
    |> Enum.map(fn key -> get(schema, key) end)
  end

  @doc """
  Gets a single record.
  """
  def get(schema, key) do
    found = :mnesia.dirty_read(:"#{schema.table_name()}_#{table_suffix()}", key)

    if length(found) > 0 do
      found
      |> hd()
      |> Tuple.to_list()
      |> tl()
      |> schema.from_list()
    end
  end

  @doc """
  Creates/updates a record.
  """
  def write(schema, attrs) do
    :ok =
      schema.fields
      |> Enum.map(fn field -> attrs[field] end)
      |> List.insert_at(0, :"#{schema.table_name()}_#{table_suffix()}")
      |> List.to_tuple()
      |> :mnesia.dirty_write()

    {:ok, struct(schema, attrs)}
  end

  @doc """
  Deletes a record.
  """
  def delete(record) do
    key_field =
      record
      |> Mnesia.Table.fields()
      |> hd()

    key = Map.get(record, key_field)

    :ok =
      record
      |> Mnesia.Table.name()
      |> Atom.to_string()
      |> Kernel.<>("_#{table_suffix()}")
      |> String.to_atom()
      |> :mnesia.dirty_delete(key)

    {:ok, record}
  end
end

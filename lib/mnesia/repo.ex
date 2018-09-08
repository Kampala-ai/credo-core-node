defmodule Mnesia.Repo do
  @doc """
  Returns the list of records.
  """
  def list(schema) do
    schema.table_name
    |> :mnesia.dirty_all_keys()
    |> Enum.map(fn key -> get(schema, key) end)
  end

  @doc """
  Gets a single record.
  """
  def get(schema, key) do
    found = :mnesia.dirty_read(schema.table_name, key)

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
      |> List.insert_at(0, schema.table_name)
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
      |> :mnesia.dirty_delete(key)

    {:ok, record}
  end
end

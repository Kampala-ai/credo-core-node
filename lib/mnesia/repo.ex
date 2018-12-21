defmodule Mnesia.Repo do
  defp table_suffix(), do: Application.get_env(:credo_core_node, Mnesia)[:table_suffix]

  def setup() do
    :mnesia.stop()
    :mnesia.create_schema([node()])
    :mnesia.start()

    # HACK: we need this to let Mnesia enough time to start properly, otherwise accessing it on app
    #   start will crash the app
    :timer.sleep(1000)

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
        table_name = :"#{module.table_name()}_#{table_suffix()}"
        module_fields = module.fields()
        :mnesia.create_table(table_name, attributes: module_fields, disc_copies: [node()])
        table_fields = :mnesia.table_info(table_name, :attributes)

        if table_fields != module_fields do
          :mnesia.transform_table(
            table_name,
            &transform_mnesia_record(&1, table_fields, module_fields),
            module_fields
          )
        end

        # HACK: using slower disc_only_copies type for now to fix the issue with saving data to disc
        :mnesia.change_table_copy_type(table_name, node(), :disc_only_copies)
      end)
    end
  end

  @doc """
  Returns the list of records.
  """
  def list(schema, limit \\ nil) do
    table_name = :"#{schema.table_name()}_#{table_suffix()}"

    fn -> :mnesia.all_keys(table_name) end
    |> :mnesia.sync_transaction()
    |> elem(1)
    |> apply_limit(limit)
    |> Enum.map(&get(schema, &1))
  end

  def apply_limit(results, limit) when is_integer(limit), do: Enum.take(results, limit)
  def apply_limit(results, limit), do: results

  @doc """
  Gets a single record.
  """
  def get(schema, key) do
    {:atomic, found} =
      fn -> :mnesia.read(:"#{schema.table_name()}_#{table_suffix()}", key) end
      |> :mnesia.sync_transaction()

    if length(found) > 0 do
      found
      |> hd()
      |> Tuple.to_list()
      |> tl()
      |> schema.from_list()
    end
  end

  @doc """
  Returns if a record is new (no record with the same key exists).
  """
  def new_record?(schema, %{} = record) do
    key = Mnesia.Record.key(record)
    new_record?(schema, key)
  end

  @doc """
  Returns if a record is new (no record with the same key exists).
  """
  def new_record?(schema, attrs) when is_list(attrs) do
    key =
      attrs
      |> hd()
      |> elem(1)

    new_record?(schema, key)
  end

  @doc """
  Returns if a record is new (no record with the same key exists).
  """
  def new_record?(schema, key) do
    !get(schema, key)
  end

  @doc """
  Creates/updates a record.
  """
  def write(schema, %{} = record), do: write(schema, Map.to_list(record))

  @doc """
  Creates/updates a record.
  """
  def write(schema, attrs) do
    table_name = :"#{schema.table_name()}_#{table_suffix()}"

    data =
      schema.fields
      |> Enum.map(fn field -> attrs[field] end)
      |> List.insert_at(0, table_name)
      |> List.to_tuple()

    {:atomic, :ok} = :mnesia.sync_transaction(fn -> :mnesia.write(data) end)

    {:ok, struct(schema, attrs)}
  end

  @doc """
  Deletes a record.
  """
  def delete(record) do
    table_name =
      record
      |> Mnesia.Table.name()
      |> Atom.to_string()
      |> Kernel.<>("_#{table_suffix()}")
      |> String.to_atom()

    key = Mnesia.Record.key(record)

    {:atomic, :ok} = :mnesia.sync_transaction(fn -> :mnesia.delete({table_name, key}) end)

    {:ok, record}
  end

  defp transform_mnesia_record(data, table_fields, module_fields) do
    [table_name | field_values] = Tuple.to_list(data)

    record =
      table_fields
      |> Enum.with_index()
      |> Enum.map(fn {fld_name, fld_idx} = _fld -> {fld_name, Enum.at(field_values, fld_idx)} end)

    transformed_field_values = Enum.map(module_fields, &record[&1])
    List.to_tuple([table_name] ++ transformed_field_values)
  end
end

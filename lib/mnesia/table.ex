defprotocol Mnesia.Table do
  @doc "Returns mnesia table name"
  def name(schema)

  @doc "Returns the list of mnesia table fields"
  def fields(schema)

  @doc "Returns the list of virtual fields that are not stored in mnesia table"
  def virtual_fields(schema)
end

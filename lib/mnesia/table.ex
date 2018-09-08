defprotocol Mnesia.Table do
  @doc "Returns mnesia table name"
  def name(schema)

  @doc "Returns the list of mnesia table fields"
  def fields(schema)
end

defmodule BlueJet.FileStorage.FileCollection.Query do
  use BlueJet, :query

  alias BlueJet.FileStorage.{FileCollection, File}

  @searchable_fields [
    :name,
    :content_type,
    :code,
    :id
  ]

  @filterable_fields [
    :id,
    :status,
    :label,
    :owner_id,
    :owner_type,
    :content_type
  ]

  def default() do
    from fc in FileCollection
  end

  def search(query, keyword, locale, default_locale) do
    search(query, @searchable_fields, keyword, locale, default_locale, File.translatable_fields())
  end

  def filter_by(query, filter) do
    filter_by(query, filter, @filterable_fields)
  end

  def for_account(query, account_id) do
    from fc in query, where: fc.account_id == ^account_id
  end

  def for_owner_type(owner_type) do
    from fc in FileCollection, where: fc.owner_type == ^owner_type
  end

  def preloads({:files, ef_preloads}, options) do
    query = File.Query.default() |> File.Query.uploaded()
    [files: {query, File.Query.preloads(ef_preloads, options)}]
  end
end
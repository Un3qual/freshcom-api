defmodule BlueJet.Notification.Email.Query do
  @behaviour BlueJet.Query

  use BlueJet, :query

  alias BlueJet.Notification.Email

  def identifiable_fields, do: [:id, :status]
  def filterable_fields, do: [:id, :status]
  def searchable_fields, do: [:to, :from, :subject, :reply_to]

  def default(), do: from(e in Email)
  def get_by(q, i), do: filter_by(q, i, identifiable_fields())
  def filter_by(q, f), do: filter_by(q, f, filterable_fields())
  def search(q, k, l, d),
    do: search(q, k, l, d, searchable_fields(), [])

  def preloads(_, _) do
    []
  end
end

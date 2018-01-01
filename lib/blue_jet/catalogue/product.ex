defmodule BlueJet.Catalogue.Product do
  @moduledoc """
  Product kinds:
  - simple
  - combo
  - with_variants
  """

  use BlueJet, :data

  use Trans, translates: [
    :name,
    :print_name,
    :short_name,
    :caption,
    :description,
    :custom_data
  ], container: :translations

  import BlueJet.Identity.Shortcut

  alias Ecto.Changeset

  alias BlueJet.AccessRequest
  alias BlueJet.Translation

  alias BlueJet.Goods

  alias BlueJet.Catalogue.Product
  alias BlueJet.Catalogue.Price
  alias BlueJet.Catalogue.ProductCollectionMembership

  schema "products" do
    field :account_id, Ecto.UUID
    field :account, :map, virtual: true

    field :status, :string, default: "draft"
    field :code, :string
    field :kind, :string, default: "simple"

    field :name_sync, :string, default: "disabled"
    field :name, :string
    field :short_name, :string
    field :print_name, :string

    field :sort_index, :integer, default: 0
    field :source_quantity, :integer, default: 1
    field :maximum_public_order_quantity, :integer, default: 999
    field :primary, :boolean, default: false
    field :auto_fulfill, :boolean, null: false, default: false

    field :caption, :string
    field :description, :string
    field :custom_data, :map, default: %{}
    field :translations, :map, default: %{}

    field :source_id, Ecto.UUID
    field :source_type, :string
    field :source, :map, virtual: true

    field :avatar_id, Ecto.UUID
    field :avatar, :map, virtual: true

    field :external_file_collections, {:array, :map}, default: [], virtual: true

    timestamps()

    belongs_to :parent, Product
    has_many :items, Product, foreign_key: :parent_id, on_delete: :delete_all
    has_many :variants, Product, foreign_key: :parent_id, on_delete: :delete_all

    has_many :prices, Price, on_delete: :delete_all
    has_one :default_price, Price
  end

  def system_fields do
    [
      :id,
      :inserted_at,
      :updated_at
    ]
  end

  def writable_fields do
    Product.__schema__(:fields) -- system_fields()
  end

  def translatable_fields do
    Product.__trans__(:fields)
  end

  def castable_fields(%{ __meta__: %{ state: :built }}) do
    writable_fields()
  end
  def castable_fields(%{ __meta__: %{ state: :loaded }}) do
    writable_fields() -- [:account_id, :kind]
  end

  def required_fields(changeset) do
    kind = get_field(changeset, :kind)

    common = [:account_id, :kind, :status, :name_sync, :name, :primary]
    case kind do
      "simple" -> common ++ [:source_quantity, :maximum_public_order_quantity, :source_id, :source_type]
      "with_variants" -> common
      "combo" -> common ++ [:maximum_public_order_quantity]
      "variant" -> common ++ [:parent_id, :source_quantity, :maximum_public_order_quantity, :sort_index, :source_id, :source_type]
      "item" -> common ++ [:parent_id, :source_quantity, :sort_index, :source_id, :source_type]
      _ -> common
    end
  end

  def validate(changeset) do
    changeset
    |> validate_required(required_fields(changeset))
    |> validate_status()
    |> validate_source()
  end

  def validate_source(changeset) do
    kind = get_field(changeset, :kind)
    validate_source(changeset, kind)
  end
  defp validate_source(changeset, "with_variants"), do: changeset
  defp validate_source(changeset, "combo"), do: changeset
  defp validate_source(changeset, _) do
    source_id = get_field(changeset, :source_id)
    source_type = get_field(changeset, :source_type)
    account_id = get_field(changeset, :account_id)

    account = get_account(%{ account: nil, account_id: account_id })
    source = get_source(%{ account: account, source_id: source_id, source_type: source_type })

    case source do
      nil -> Changeset.add_error(changeset, :source_id, "is invalid")
      _ -> changeset
    end
  end

  def validate_status(changeset) do
    kind = get_field(changeset, :kind)
    validate_status(changeset, kind)
  end

  defp validate_status(changeset = %Changeset{ changes: %{ status: "active" } }, "variant") do
    validate_status(changeset, "simple")
  end
  defp validate_status(changeset = %Changeset{ changes: %{ status: "active" } }, "simple") do
    id = get_field(changeset, :id)

    active_price = if id do
      Repo.get_by(Price, product_id: id, status: "active")
    else
      nil
    end

    case active_price do
      nil -> Changeset.add_error(changeset, :status, "A Product must have a Active Price in order to be marked Active.", [validation: "require_active_price", full_error_message: true])
      _ -> changeset
    end
  end
  defp validate_status(changeset = %Changeset{ changes: %{ status: "active" } }, "with_variants") do
    id = get_field(changeset, :id)

    active_primary_item = if id do
      Repo.get_by(Product, parent_id: id, status: "active", primary: true)
    else
      nil
    end

    case active_primary_item do
      nil -> Changeset.add_error(changeset, :status, "A Product with variants must have a Primary Active Variant in order to be marked Active.", [validation: "require_primary_active_variant", full_error_message: true])
      _ -> changeset
    end
  end
  defp validate_status(changeset = %Changeset{ changes: %{ status: "active" } }, "combo") do
    items = Ecto.assoc(changeset.data, :items)
    item_count = Ecto.assoc(changeset.data, :items) |> Repo.aggregate(:count, :id)
    active_item_count = from(p in items, where: p.status == "active") |> Repo.aggregate(:count, :id)

    prices = Ecto.assoc(changeset.data, :prices)
    active_price_count = from(p in prices, where: p.status == "active") |> Repo.aggregate(:count, :id)

    cond do
      active_item_count != item_count -> Changeset.add_error(changeset, :status, "A Product combo must have all of its Item set to Active in order to be marked Active.", [validation: "require_all_item_active", full_error_message: true])
      active_price_count == 0 -> Changeset.add_error(changeset, :status, "A Product Combo require at least one Active Price in order to be marked Active.", [validation: "require_at_least_one_active_price", full_error_message: true])
      true -> changeset
    end
  end
  defp validate_status(changeset = %Changeset{ changes: %{ status: "internal" } }, "variant") do
    validate_status(changeset, "simple")
  end
  defp validate_status(changeset = %Changeset{ changes: %{ status: "internal" } }, "simple") do
    prices = Ecto.assoc(changeset.data, :prices)
    ai_price_count = from(p in prices, where: p.status in ["active", "internal"]) |> Repo.aggregate(:count, :id)

    if ai_price_count > 0 do
      changeset
    else
      Changeset.add_error(changeset, :status, "A Product must have a Active/Internal Price in order to be marked Internal.", [validation: "require_internal_price", full_error_message: true])
    end
  end
  defp validate_status(changeset = %Changeset{ changes: %{ status: "internal" } }, "with_variants") do
    variants = Ecto.assoc(changeset.data, :variants)
    active_or_internal_variants = from(p in variants, where: p.status in ["active", "internal"])
    aiv_count = Repo.aggregate(active_or_internal_variants, :count, :id)

    case aiv_count do
      0 -> Changeset.add_error(changeset, :status, "A Product with variants must have at least one Active/Internal Variant in order to be marked Internal.", [validation: "require_at_least_one_internal_variant", full_error_message: true])
      _ -> changeset
    end
  end
  defp validate_status(changeset = %Changeset{ changes: %{ status: "internal" } }, "combo") do
    items = Ecto.assoc(changeset.data, :items)
    item_count = items |> Repo.aggregate(:count, :id)
    aip_count = from(p in items, where: p.status in ["active", "internal"]) |> Repo.aggregate(:count, :id)

    prices = Ecto.assoc(changeset.data, :prices)
    ai_price_count = from(p in prices, where: p.status in ["active", "internal"]) |> Repo.aggregate(:count, :id)

    cond do
      aip_count != item_count -> Changeset.add_error(changeset, :status, "A Product combo must have all of its Item set to Active/Internal in order to be marked Internal.", [validation: "require_all_item_internal", full_error_message: true])
      ai_price_count == 0 -> Changeset.add_error(changeset, :status, "A Product combo require at least one Active/Internal Price in order to be marked Internal.", [validation: "require_at_least_one_internal_price", full_error_message: true])
      true -> changeset
    end
  end
  defp validate_status(changeset, _), do: changeset


  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params, locale \\ nil, default_locale \\ nil) do
    struct
    |> cast(params, castable_fields(struct))
    |> put_name(locale)
    |> validate()
    |> Translation.put_change(translatable_fields(), locale, default_locale)
  end

  def get_source(product, locale \\ nil)

  def get_source(product = %{ source_id: source_id, source_type: "Stockable" }, locale) do
    account = get_account(product)
    response = Goods.do_get_stockable(%AccessRequest{
      account: account,
      params: %{ "id" => source_id },
      locale: locale || account.default_locale
    })

    case response do
      {:ok, %{ data: stockable }} -> stockable
      {:error, _} -> nil
    end
  end

  def get_source(product = %{ source_id: source_id, source_type: "Unlockable" }, locale) do
    account = get_account(product)
    response = Goods.do_get_unlockable(%AccessRequest{
      account: account,
      params: %{ "id" => source_id },
      locale: locale || account.default_locale
    })

    case response do
      {:ok, %{ data: unlockable }} -> unlockable
      {:error, _} -> nil
    end
  end

  def get_source(product = %{ source_id: source_id, source_type: "Depositable" }, locale) do
    account = get_account(product)
    response = Goods.do_get_depositable(%AccessRequest{
      account: account,
      params: %{ "id" => source_id },
      locale: locale || account.default_locale
    })

    case response do
      {:ok, %{ data: depositable }} -> depositable
      {:error, _} -> nil
    end
  end

  def get_source(_, _), do: nil

  def put_name(changeset = %Changeset{ valid?: true, changes: %{ name_sync: "sync_with_source" } }, _) do
    source_id = get_field(changeset, :source_id)
    source_type = get_field(changeset, :source_type)
    account_id = get_field(changeset, :account_id)

    account = get_account(%{ account: nil, account_id: account_id })
    source = get_source(%{ account: account, source_id: source_id, source_type: source_type })

    if source do
      changeset = put_change(changeset, :name, "#{source.name}")

      new_translations =
        changeset
        |> Changeset.get_field(:translations)
        |> Translation.merge_translations(source.translations, ["name"])

      put_change(changeset, :translations, new_translations)
    else
      changeset
    end
  end
  def put_name(changeset, _), do: changeset

  ####
  # External Resources
  ###
  use BlueJet.FileStorage.Macro,
    put_external_resources: :external_file,
    field: :avatar

  use BlueJet.FileStorage.Macro,
    put_external_resources: :external_file_collection,
    field: :external_file_collections,
    owner_type: "Product"

  def put_external_resources(stockable, _, _), do: stockable

  defmodule Query do
    use BlueJet, :query

    def default() do
      from p in Product, order_by: [desc: p.updated_at]
    end

    def for_account(query, account_id) do
      from(p in query, where: p.account_id == ^account_id)
    end

    def in_collection(query, nil), do: query
    def in_collection(query, collection_id) do
      from p in query,
        join: pcm in ProductCollectionMembership, on: pcm.product_id == p.id,
        where: pcm.collection_id == ^collection_id,
        order_by: [desc: pcm.sort_index]
    end

    def variant_default() do
      from(p in Product, where: p.kind == "variant", order_by: [desc: :updated_at])
    end

    def item_default() do
      from(p in Product, where: p.kind == "item", order_by: [desc: :updated_at])
    end

    def preloads({:items, item_preloads}, options = [role: role]) when role in ["guest", "customer"] do
      query = Product.Query.default() |> Product.Query.active()
      [items: {query, Product.Query.preloads(item_preloads, options)}]
    end

    def preloads({:items, item_preloads}, options = [role: _]) do
      query = Product.Query.default()
      [items: {query, Product.Query.preloads(item_preloads, options)}]
    end

    def preloads({:variants, item_preloads}, options = [role: role]) when role in ["guest", "customer"] do
      query = Product.Query.default() |> Product.Query.active()
      [variants: {query, Product.Query.preloads(item_preloads, options)}]
    end

    def preloads({:variants, item_preloads}, options = [role: _]) do
      query = Product.Query.default()
      [variants: {query, Product.Query.preloads(item_preloads, options)}]
    end

    def preloads({:prices, price_preloads}, options = [role: role]) when role in ["guest", "customer"] do
      query = Price.Query.default() |> Price.Query.active()
      [prices: {query, Price.Query.preloads(price_preloads, options)}]
    end

    def preloads({:prices, price_preloads}, options = [role: _]) do
      query = Price.Query.default()
      [prices: {query, Price.Query.preloads(price_preloads, options)}]
    end

    def preloads({:default_price, price_preloads}, options) do
      query = Price.Query.active_by_moq()
      [default_price: {query, Price.Query.preloads(price_preloads, options)}]
    end

    def preloads(_, _) do
      []
    end

    def root(query) do
      from(p in query, where: is_nil(p.parent_id))
    end

    def active(query) do
      from(p in query, where: p.status == "active")
    end
  end
end

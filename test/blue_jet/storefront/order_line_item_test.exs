defmodule BlueJet.OrderLineItemTest do
  use BlueJet.DataCase

  import Mox

  alias Decimal, as: D

  alias BlueJet.Identity.Account
  alias BlueJet.Catalogue.{Product, Price}
  alias BlueJet.Goods.{Stockable}
  alias BlueJet.Fulfillment.{FulfillmentItem}

  alias BlueJet.Storefront.{Order, OrderLineItem}
  alias BlueJet.Storefront.{CatalogueServiceMock, GoodsServiceMock, FulfillmentServiceMock}

  describe "schema" do
    test "when order is deleted line item should be deleted automatically" do
      account = Repo.insert!(%Account{})
      order = Repo.insert!(%Order{
        account_id: account.id
      })
      oli = Repo.insert!(%OrderLineItem{
        account_id: account.id,
        order_id: order.id,
        name: Faker.String.base64(5),
        sub_total_cents: 500,
        grand_total_cents: 500,
        authorization_total_cents: 500,
        charge_quantity: 1,
        auto_fulfill: false
      })
      Repo.delete!(order)

      refute Repo.get(OrderLineItem, oli.id)
    end

    test "when parent is deleted, children should be deleted automatically" do
      account = Repo.insert!(%Account{})
      order = Repo.insert!(%Order{
        account_id: account.id
      })
      parent_oli = Repo.insert!(%OrderLineItem{
        account_id: account.id,
        order_id: order.id,
        name: Faker.String.base64(5),
        sub_total_cents: 500,
        grand_total_cents: 500,
        authorization_total_cents: 500,
        charge_quantity: 1,
        auto_fulfill: false
      })
      child_oli = Repo.insert!(%OrderLineItem{
        account_id: account.id,
        order_id: order.id,
        parent_id: parent_oli.id,
        name: Faker.String.base64(5),
        sub_total_cents: 500,
        grand_total_cents: 500,
        authorization_total_cents: 500,
        charge_quantity: 1,
        auto_fulfill: false
      })

      Repo.delete!(parent_oli)

      refute Repo.get(OrderLineItem, child_oli.id)
    end

    test "defaults" do
      oli = %OrderLineItem{}

      assert oli.fulfillment_status == "pending"
      assert oli.is_leaf
      assert oli.order_quantity == 1
      assert oli.tax_one_cents == 0
      assert oli.tax_two_cents == 0
      assert oli.tax_three_cents == 0
      assert oli.is_estimate == false
      assert oli.custom_data == %{}
      assert oli.translations == %{}
    end
  end

  test "writable_fields/0" do
    assert OrderLineItem.writable_fields() == [
      :code,
      :name,
      :label,
      :sort_index,
      :fulfillment_status,
      :print_name,
      :is_leaf,
      :order_quantity,
      :charge_quantity,
      :sub_total_cents,
      :tax_one_cents,
      :tax_two_cents,
      :tax_three_cents,
      :authorization_total_cents,
      :is_estimate,
      :auto_fulfill,
      :caption,
      :description,
      :custom_data,
      :translations,
      :target_id,
      :target_type,
      :product_id,
      :price_id,
      :parent_id,
      :order_id
    ]
  end

  describe "validate/1" do
    test "when line item is missing required fields" do
      changeset =
        change(%OrderLineItem{}, %{})
        |> OrderLineItem.validate()

      refute changeset.valid?
      assert Keyword.keys(changeset.errors) == [
        :order_id,
        :name,
        :charge_quantity,
        :sub_total_cents,
        :grand_total_cents,
        :authorization_total_cents,
        :auto_fulfill
      ]
    end

    test "when order_id is invalid" do
      account = Repo.insert!(%Account{})
      order = Repo.insert!(%Order{
        account_id: account.id
      })

      changeset =
        change(%OrderLineItem{}, %{
          order_id: order.id,
          product_id: Ecto.UUID.generate(),
          name: Faker.String.base64(5),
          charge_quantity: 1,
          sub_total_cents: 500,
          grand_total_cents: 500,
          authorization_total_cents: 500,
          auto_fulfill: false
        })
        |> OrderLineItem.validate()

      refute changeset.valid?
      assert Keyword.keys(changeset.errors) == [:order]
    end

    test "when product_id is invalid" do
      account = Repo.insert!(%Account{})
      order = Repo.insert!(%Order{
        account_id: account.id
      })

      CatalogueServiceMock
      |> expect(:get_product, fn(_, _) -> nil end)

      changeset =
        change(%OrderLineItem{ account_id: account.id, account: account }, %{
          order_id: order.id,
          product_id: Ecto.UUID.generate(),
          name: Faker.String.base64(5),
          charge_quantity: 1,
          sub_total_cents: 500,
          grand_total_cents: 500,
          authorization_total_cents: 500,
          auto_fulfill: false
        })
        |> OrderLineItem.validate()

      verify!()
      refute changeset.valid?
      assert Keyword.keys(changeset.errors) == [:product]
    end

    test "when price_id is invalid" do
      account = Repo.insert!(%Account{})
      order = Repo.insert!(%Order{
        account_id: account.id
      })

      product_id = Ecto.UUID.generate()
      product = %Product{
        id: product_id,
        account_id: account.id
      }
      CatalogueServiceMock
      |> expect(:get_product, fn(_, _) -> product end)
      |> expect(:get_price, fn(_, _) -> nil end)

      changeset =
        change(%OrderLineItem{ account_id: account.id, account: account }, %{
          order_id: order.id,
          product_id: product_id,
          price_id: Ecto.UUID.generate(),
          name: Faker.String.base64(5),
          charge_quantity: 1,
          sub_total_cents: 500,
          grand_total_cents: 500,
          authorization_total_cents: 500,
          auto_fulfill: false
        })
        |> OrderLineItem.validate()

      verify!()
      refute changeset.valid?
      assert Keyword.keys(changeset.errors) == [:price]
    end
  end

  describe "changeset/4" do
    test "when given line item with product id" do
      account = %Account{ }
      product = %Product{
        id: Ecto.UUID.generate(),
        name: Faker.String.base64(5)
      }
      CatalogueServiceMock
      |> expect(:get_product, fn(_, _) -> product end)
      |> expect(:get_price, fn(_, _) -> nil end)

      oli = %OrderLineItem{ account: account }
      changeset = OrderLineItem.changeset(oli, :insert, %{
        product_id: Ecto.UUID.generate(),
        sub_total_cents: 1000,
        tax_one_cents: 500,
        tax_two_cents: 300,
        tax_three_cents: 200
      })

      verify!()
      assert changeset.changes[:is_leaf] == false
      assert changeset.changes[:name] == product.name
      assert changeset.changes[:print_name] == product.name
      assert changeset.changes[:auto_fulfill] == false
      assert changeset.changes[:charge_quantity] == D.new(1)
      assert changeset.changes[:sub_total_cents] == 1000
      assert changeset.changes[:grand_total_cents] == 2000
      assert changeset.changes[:authorization_total_cents] == 2000
    end

    test "when given line item with price id" do
      account = %Account{
        id: Ecto.UUID.generate()
      }

      product = %Product{
        id: Ecto.UUID.generate(),
        account_id: account.id,
        name: Faker.String.base64(5)
      }
      price = %Price{
        id: Ecto.UUID.generate(),
        product_id: product.id,
        name: Faker.String.base64(5),
        label: Faker.String.base64(5),
        caption: Faker.String.base64(5),
        order_unit: Faker.String.base64(2),
        charge_unit: Faker.String.base64(2),
        currency_code: Faker.String.base64(3),
        charge_amount_cents: 500,
        estimate_average_percentage: D.new(150),
        estimate_maximum_percentage: D.new(200),
        estimate_by_default: true,
        tax_one_percentage: D.new(7),
        tax_two_percentage: D.new(10),
        tax_three_percentage: D.new(15)
      }
      CatalogueServiceMock
      |> expect(:get_product, fn(_, _) -> product end)
      |> expect(:get_price, fn(_, _) -> price end)

      changeset =
        %OrderLineItem{ account_id: account.id, account: account }
        |> OrderLineItem.changeset(:insert, %{ product_id: Ecto.UUID.generate() })

      verify!()
      assert changeset.changes[:price_name] == price.name
      assert changeset.changes[:price_label] == price.label
      assert changeset.changes[:price_caption] == price.caption
      assert changeset.changes[:price_order_unit] == price.order_unit
      assert changeset.changes[:price_charge_unit] == price.charge_unit
      assert changeset.changes[:price_currency_code] == price.currency_code
      assert changeset.changes[:price_charge_amount_cents] == price.charge_amount_cents
      assert changeset.changes[:price_estimate_average_percentage] == price.estimate_average_percentage
      assert changeset.changes[:price_estimate_maximum_percentage] == price.estimate_maximum_percentage
      assert changeset.changes[:price_estimate_by_default] == price.estimate_by_default
      assert changeset.changes[:price_tax_one_percentage] == price.tax_one_percentage
      assert changeset.changes[:price_tax_two_percentage] == price.tax_two_percentage
      assert changeset.changes[:price_tax_three_percentage] == price.tax_three_percentage
      assert changeset.changes[:is_estimate] == true
      assert changeset.changes[:charge_quantity] == price.estimate_average_percentage |> D.div(D.new(100)) |> D.mult(D.new(1))
      assert changeset.changes[:sub_total_cents] == 750
      assert changeset.changes[:tax_one_cents] == 53
      assert changeset.changes[:tax_two_cents] == 75
      assert changeset.changes[:tax_three_cents] == 113
      assert changeset.changes[:grand_total_cents] == 991
      assert changeset.changes[:authorization_total_cents] == 1320
    end
  end

  describe "balance/1" do
    test "when is leaf and has no parent" do
      oli = %OrderLineItem{ is_leaf: true }
      assert OrderLineItem.balance(oli) == {:ok, oli}
    end

    test "when oli is for simple product" do
      account = Repo.insert!(%Account{})

      stockable = %Stockable{
        id: Ecto.UUID.generate(),
        name: Faker.String.base64(5)
      }
      GoodsServiceMock
      |> expect(:get_stockable, fn(_, _) -> stockable end)

      product = Repo.insert!(%Product{
        account_id: account.id,
        name: Faker.String.base64(5),
        goods_quantity: 2,
        goods_id: stockable.id,
        goods_type: "Stockable"
      })

      CatalogueServiceMock
      |> expect(:get_product, fn(_, _) -> product end)

      order = Repo.insert!(%Order{
        account_id: account.id
      })
      oli = Repo.insert!(%OrderLineItem{
        account: account,
        account_id: account.id,
        product_id: product.id,
        order_id: order.id,
        name: Faker.String.base64(5),
        is_leaf: false,
        auto_fulfill: false,
        charge_quantity: Decimal.new(2),
        sub_total_cents: 500,
        tax_one_cents: 200,
        tax_two_cents: 500,
        tax_three_cents: 300,
        grand_total_cents: 1500,
        authorization_total_cents: 1500
      })

      {:ok, oli} = OrderLineItem.balance(oli)

      verify!()
      child = Repo.get_by(OrderLineItem, parent_id: oli.id)
      assert child.is_leaf == true
      assert child.name == stockable.name
      assert child.target_id == stockable.id
      assert child.target_type == "Stockable"
      assert child.order_id == oli.order_id
      assert child.sub_total_cents == oli.sub_total_cents
      assert child.tax_one_cents == oli.tax_one_cents
      assert child.tax_two_cents == oli.tax_two_cents
      assert child.tax_three_cents == oli.tax_three_cents
      assert child.grand_total_cents == oli.grand_total_cents
      assert child.authorization_total_cents == oli.authorization_total_cents
      assert child.auto_fulfill == oli.auto_fulfill
      assert child.order_quantity == oli.order_quantity * product.goods_quantity
      assert child.charge_quantity == oli.charge_quantity
    end

    test "when oli is for product combo" do
      account = Repo.insert!(%Account{})

      stockable1 = %Stockable{
        id: Ecto.UUID.generate(),
        name: Faker.String.base64(5)
      }

      stockable2 = %Stockable{
        id: Ecto.UUID.generate(),
        name: Faker.String.base64(5)
      }

      product = Repo.insert!(%Product{
        id: Ecto.UUID.generate(),
        account_id: account.id,
        kind: "combo",
        name: Faker.String.base64(5)
      })

      item1 = Repo.insert!(%Product{
        id: Ecto.UUID.generate(),
        account_id: account.id,
        kind: "item",
        price_proportion_index: 20,
        name: Faker.String.base64(5),
        parent_id: product.id,
        goods_type: "Stockable",
        goods_id: stockable1.id
      })

      item2 = Repo.insert!(%Product{
        id: Ecto.UUID.generate(),
        account_id: account.id,
        kind: "item",
        price_proportion_index: 30,
        name: Faker.String.base64(5),
        parent_id: product.id,
        goods_type: "Stockable",
        goods_id: stockable1.id
      })

      order = Repo.insert!(%Order{
        account_id: account.id
      })

      CatalogueServiceMock
      |> expect(:get_product, fn(_, _) -> product end)
      |> expect(:list_product, fn(_, _) -> [item1, item2] end)
      |> expect(:get_price, fn(_, _) -> nil end)
      |> expect(:get_price, fn(_, _) -> nil end)

      GoodsServiceMock
      |> expect(:get_stockable, fn(_, _) -> stockable1 end)
      |> expect(:get_stockable, fn(_, _) -> stockable2 end)


      oli = Repo.insert!(%OrderLineItem{
        account: account,
        account_id: account.id,
        product_id: product.id,
        order_id: order.id,
        name: Faker.String.base64(5),
        is_leaf: false,
        auto_fulfill: false,
        charge_quantity: Decimal.new(2),
        sub_total_cents: 500,
        tax_one_cents: 200,
        tax_two_cents: 500,
        tax_three_cents: 300,
        grand_total_cents: 1500,
        authorization_total_cents: 1500
      })

      {:ok, _} = OrderLineItem.balance(oli)

      parent_id = oli.id
      children =
        from(q in OrderLineItem, where: q.parent_id == ^parent_id)
        |> Repo.all()

      verify!()
      assert length(children) == 2
      assert Enum.reduce(children, 0, fn(child, acc) -> child.sub_total_cents + acc end) == 500
      assert Enum.reduce(children, 0, fn(child, acc) -> child.tax_one_cents + acc end) == 200
      assert Enum.reduce(children, 0, fn(child, acc) -> child.tax_two_cents + acc end) == 500
      assert Enum.reduce(children, 0, fn(child, acc) -> child.tax_three_cents + acc end) == 300
      assert Enum.reduce(children, 0, fn(child, acc) -> child.grand_total_cents + acc end) == 1500
    end
  end

  describe "get_fulfillment_status/1" do
    test "when there is no fulfillment item" do
      fulfillment_items = []
      FulfillmentServiceMock
      |> expect(:list_fulfillment_item, fn(_, _) -> fulfillment_items end)

      result = OrderLineItem.get_fulfillment_status(%OrderLineItem{ order_quantity: 5 })

      verify!()
      assert result == "pending"
    end

    test "when all corresponding fulfillment item is returned" do
      fulfillment_items = [
        %FulfillmentItem{ status: "returned", quantity: 2, returned_quantity: 2, gross_quantity: 0 },
        %FulfillmentItem{ status: "returned", quantity: 3, returned_quantity: 3, gross_quantity: 0 }
      ]
      FulfillmentServiceMock
      |> expect(:list_fulfillment_item, fn(_, _) -> fulfillment_items end)

      result = OrderLineItem.get_fulfillment_status(%OrderLineItem{ order_quantity: 5 })

      verify!()
      assert result == "returned"
    end

    test "when some of the fulfillment item is fulfilled" do
      fulfillment_items = [
        %FulfillmentItem{ status: "fulfilled", quantity: 2, gross_quantity: 2 },
        %FulfillmentItem{ status: "pending", quantity: 1, gross_quantity: 1 }
      ]
      FulfillmentServiceMock
      |> expect(:list_fulfillment_item, fn(_, _) -> fulfillment_items end)

      result = OrderLineItem.get_fulfillment_status(%OrderLineItem{ order_quantity: 5 })

      verify!()
      assert result == "partially_fulfilled"
    end

    test "when all of fulfillment item is fulfilled" do
      fulfillment_items = [
        %FulfillmentItem{ status: "fulfilled", quantity: 2, gross_quantity: 2 },
        %FulfillmentItem{ status: "fulfilled", quantity: 3, gross_quantity: 3 }
      ]
      FulfillmentServiceMock
      |> expect(:list_fulfillment_item, fn(_, _) -> fulfillment_items end)

      result = OrderLineItem.get_fulfillment_status(%OrderLineItem{ order_quantity: 5 })

      verify!()
      assert result == "fulfilled"
    end
  end
end

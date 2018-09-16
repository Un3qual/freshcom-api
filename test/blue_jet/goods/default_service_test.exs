defmodule BlueJet.Goods.DefaultServiceTest do
  use BlueJet.DataCase

  alias BlueJet.Goods.{Stockable, Unlockable, Depositable}
  alias BlueJet.Goods.DefaultService

  def stockable_fixture(account, fields \\ %{}) do
    default_fields = %{
      name: Faker.Commerce.product_name(),
      unit_of_measure: "EA"
    }
    fields = Map.merge(default_fields, fields)

    {:ok, stockable} = DefaultService.create_stockable(fields, %{account: account})

    stockable
  end

  def unlockable_fixture(account, fields \\ %{}) do
    default_fields = %{
      name: Faker.Commerce.product_name()
    }
    fields = Map.merge(default_fields, fields)

    {:ok, unlockable} = DefaultService.create_unlockable(fields, %{account: account})

    unlockable
  end

  def depositable_fixture(account, fields \\ %{}) do
    default_fields = %{
      name: Faker.Commerce.product_name(),
      gateway: "freshcom",
      amount: System.unique_integer([:positive])
    }
    fields = Map.merge(default_fields, fields)

    {:ok, depositable} = DefaultService.create_depositable(fields, %{account: account})

    depositable
  end

  #
  # MARK: Stockable
  #
  describe "list_stockable/2 and count_stockable/2" do
    test "with valid request" do
      account1 = account_fixture()
      account2 = account_fixture()

      stockable_fixture(account1, %{label: "colored_shirt", name: "Blue Shirt"})
      stockable_fixture(account1, %{label: "colored_shirt", name: "White Shirt"})
      stockable_fixture(account1, %{label: "colored_shirt", name: "Black Shirt"})
      stockable_fixture(account1, %{name: "Yellow Shirt"})
      stockable_fixture(account1)
      stockable_fixture(account1)

      stockable_fixture(account2, %{label: "colored_shirt", name: "Blue Shirt"})

      query = %{
        filter: %{label: "colored_shirt"},
        search: "shirt"
      }

      stockables = DefaultService.list_stockable(query, %{
        account: account1,
        pagination: %{size: 2, number: 1}
      })

      assert length(stockables) == 2

      stockables = DefaultService.list_stockable(query, %{
        account: account1,
        pagination: %{size: 2, number: 2}
      })

      assert length(stockables) == 1

      assert DefaultService.count_stockable(query, %{account: account1}) == 3
      assert DefaultService.count_stockable(%{}, %{account: account1}) == 6
    end
  end

  describe "create_stockable/2" do
    test "when given invalid fields" do
      account = account_fixture()

      {:error, %{errors: _}} = DefaultService.create_stockable(%{}, %{account: account})
    end

    test "when given valid fields" do
      account = account_fixture()

      fields = %{
        "name" => Faker.Commerce.product_name(),
        "unit_of_measure" => "ea"
      }

      {:ok, stockable} = DefaultService.create_stockable(fields, %{account: account})

      assert stockable.name == fields["name"]
      assert stockable.unit_of_measure == fields["unit_of_measure"]
      assert stockable.account.id == account.id
    end
  end

  describe "get_stockable/2" do
    test "when give id does not exist" do
      account = account_fixture()

      refute DefaultService.get_stockable(%{id: Ecto.UUID.generate()}, %{account: account})
    end

    test "when given id belongs to a different account" do
      account1 = account_fixture()
      account2 = account_fixture()
      stockable = stockable_fixture(account1)

      refute DefaultService.get_stockable(%{id: stockable.id}, %{account: account2})
    end

    test "when given id" do
      account = account_fixture()
      target_stockable = stockable_fixture(account)

      stockable = DefaultService.get_stockable(%{id: target_stockable.id}, %{account: account})

      assert stockable.id == target_stockable.id
      assert stockable.account.id == account.id
    end
  end

  describe "update_stockable/2" do
    test "when given id does not exist" do
      account = account_fixture()

      identifiers = %{id: Ecto.UUID.generate()}
      opts = %{account: account}
      {:error, error} = DefaultService.update_stockable(identifiers, %{}, opts)

      assert error == :not_found
    end

    test "when given id belongs to a different account" do
      account1 = account_fixture()
      account2 = account_fixture()
      stockable = stockable_fixture(account1)

      identifiers = %{id: stockable.id}
      opts = %{account: account2}

      {:error, error} = DefaultService.update_stockable(identifiers, %{}, opts)

      assert error == :not_found
    end

    test "when given valid id and valid fields" do
      account = account_fixture()
      target_stockable = stockable_fixture(account)

      identifiers = %{id: target_stockable.id}
      fields = %{"name" => Faker.Commerce.product_name()}
      opts = %{account: account}

      {:ok, stockable} = DefaultService.update_stockable(identifiers, fields, opts)

      assert stockable.name == fields["name"]
    end
  end

  describe "delete_stockable/2" do
    test "when given id does not exist" do
      account = account_fixture()

      identifiers = %{id: Ecto.UUID.generate()}
      opts = %{account: account}

      {:error, error} = DefaultService.delete_stockable(identifiers, opts)

      assert error == :not_found
    end

    test "when given id belongs to a different account" do
      account1 = account_fixture()
      account2 = account_fixture()
      stockable = stockable_fixture(account1)

      identifiers = %{id: stockable.id}
      opts = %{account: account2}

      {:error, error} = DefaultService.delete_stockable(identifiers, opts)

      assert error == :not_found
    end

    test "when given valid id" do
      account = account_fixture()
      stockable = stockable_fixture(account)

      identifiers = %{id: stockable.id}
      opts = %{account: account}

      {:ok, stockable} = DefaultService.delete_stockable(identifiers, opts)

      assert stockable
      refute Repo.get(Stockable, stockable.id)
    end
  end

  describe "delete_all_stockable/1" do
    test "given valid account" do
      account = account_fixture()
      test_account = account.test_account
      stockable1 = stockable_fixture(test_account)
      stockable2 = stockable_fixture(test_account)

      :ok = DefaultService.delete_all_stockable(%{account: test_account})

      refute Repo.get(Stockable, stockable1.id)
      refute Repo.get(Stockable, stockable2.id)
    end
  end

  #
  # MARK: Unlockable
  #
  describe "list_unlockable/2 and count_unlockable/2" do
    test "with valid request" do
      account1 = account_fixture()
      account2 = account_fixture()

      unlockable_fixture(account1, %{label: "bestseller", name: "Audio Book #1"})
      unlockable_fixture(account1, %{label: "bestseller", name: "Audio Book #2"})
      unlockable_fixture(account1, %{label: "bestseller", name: "Audio Book #3"})
      unlockable_fixture(account1, %{name: "Audio Book #99"})
      unlockable_fixture(account1)
      unlockable_fixture(account1)

      unlockable_fixture(account2, %{label: "bestseller", name: "Audio Book #1"})

      query = %{
        filter: %{label: "bestseller"},
        search: "book"
      }

      unlockables = DefaultService.list_unlockable(query, %{
        account: account1,
        pagination: %{size: 2, number: 1}
      })

      assert length(unlockables) == 2

      unlockables = DefaultService.list_unlockable(query, %{
        account: account1,
        pagination: %{size: 2, number: 2}
      })

      assert length(unlockables) == 1

      assert DefaultService.count_unlockable(query, %{account: account1}) == 3
      assert DefaultService.count_unlockable(%{}, %{account: account1}) == 6
    end
  end

  describe "create_unlockable/2" do
    test "when given invalid fields" do
      account = account_fixture()

      {:error, %{errors: _}} = DefaultService.create_unlockable(%{}, %{account: account})
    end

    test "when given valid fields" do
      account = account_fixture()

      fields = %{
        "name" => Faker.Commerce.product_name()
      }

      {:ok, unlockable} = DefaultService.create_unlockable(fields, %{account: account})

      assert unlockable.name == fields["name"]
      assert unlockable.account.id == account.id
    end
  end

  describe "get_unlockable/2" do
    test "when give id does not exist" do
      account = account_fixture()

      refute DefaultService.get_unlockable(%{id: Ecto.UUID.generate()}, %{account: account})
    end

    test "when given id belongs to a different account" do
      account1 = account_fixture()
      account2 = account_fixture()
      unlockable = unlockable_fixture(account1)

      refute DefaultService.get_unlockable(%{id: unlockable.id}, %{account: account2})
    end

    test "when given id" do
      account = account_fixture()
      target_unlockable = unlockable_fixture(account)

      unlockable = DefaultService.get_unlockable(%{id: target_unlockable.id}, %{account: account})

      assert unlockable.id == target_unlockable.id
      assert unlockable.account.id == account.id
    end
  end

  describe "update_unlockable/2" do
    test "when given id does not exist" do
      account = account_fixture()

      identifiers = %{id: Ecto.UUID.generate()}
      opts = %{account: account}
      {:error, error} = DefaultService.update_unlockable(identifiers, %{}, opts)

      assert error == :not_found
    end

    test "when given id belongs to a different account" do
      account1 = account_fixture()
      account2 = account_fixture()
      unlockable = unlockable_fixture(account1)

      identifiers = %{id: unlockable.id}
      opts = %{account: account2}

      {:error, error} = DefaultService.update_unlockable(identifiers, %{}, opts)

      assert error == :not_found
    end

    test "when given valid id and valid fields" do
      account = account_fixture()
      target_unlockable = unlockable_fixture(account)

      identifiers = %{id: target_unlockable.id}
      fields = %{"name" => Faker.Commerce.product_name()}
      opts = %{account: account}

      {:ok, unlockable} = DefaultService.update_unlockable(identifiers, fields, opts)

      assert unlockable.name == fields["name"]
    end
  end

  describe "delete_unlockable/2" do
    test "when given id does not exist" do
      account = account_fixture()

      identifiers = %{id: Ecto.UUID.generate()}
      opts = %{account: account}

      {:error, error} = DefaultService.delete_unlockable(identifiers, opts)

      assert error == :not_found
    end

    test "when given id belongs to a different account" do
      account1 = account_fixture()
      account2 = account_fixture()
      unlockable = unlockable_fixture(account1)

      identifiers = %{id: unlockable.id}
      opts = %{account: account2}

      {:error, error} = DefaultService.delete_unlockable(identifiers, opts)

      assert error == :not_found
    end

    test "when given valid id" do
      account = account_fixture()
      unlockable = unlockable_fixture(account)

      identifiers = %{id: unlockable.id}
      opts = %{account: account}

      {:ok, unlockable} = DefaultService.delete_unlockable(identifiers, opts)

      assert unlockable
      refute Repo.get(Unlockable, unlockable.id)
    end
  end

  describe "delete_all_unlockable/1" do
    test "given valid account" do
      account = account_fixture()
      test_account = account.test_account
      unlockable1 = unlockable_fixture(test_account)
      unlockable2 = unlockable_fixture(test_account)

      :ok = DefaultService.delete_all_unlockable(%{account: test_account})

      refute Repo.get(Unlockable, unlockable1.id)
      refute Repo.get(Unlockable, unlockable2.id)
    end
  end

  describe "list_depositable/2 and count_depositable/2" do
    test "with valid request" do
      account1 = account_fixture()
      account2 = account_fixture()

      depositable_fixture(account1, %{label: "promotion", name: "$50 Gift Card"})
      depositable_fixture(account1, %{label: "promotion", name: "$100 Gift Card"})
      depositable_fixture(account1, %{label: "promotion", name: "$200 Gift Card"})
      depositable_fixture(account1, %{name: "$20 Gift Card"})
      depositable_fixture(account1)
      depositable_fixture(account1)

      depositable_fixture(account2, %{label: "promotion", name: "$100 Gift Card"})

      query = %{
        filter: %{label: "promotion"},
        search: "gift"
      }

      depositables = DefaultService.list_depositable(query, %{
        account: account1,
        pagination: %{size: 2, number: 1}
      })

      assert length(depositables) == 2

      depositables = DefaultService.list_depositable(query, %{
        account: account1,
        pagination: %{size: 2, number: 2}
      })

      assert length(depositables) == 1

      assert DefaultService.count_depositable(query, %{account: account1}) == 3
      assert DefaultService.count_depositable(%{}, %{account: account1}) == 6
    end
  end

  describe "create_depositable/2" do
    test "when given invalid fields" do
      account = account_fixture()

      {:error, %{errors: _}} = DefaultService.create_depositable(%{}, %{account: account})
    end

    test "when given valid fields" do
      account = account_fixture()

      fields = %{
        "name" => Faker.Commerce.product_name(),
        "gateway" => "freshcom",
        "amount" => 1234
      }

      {:ok, depositable} = DefaultService.create_depositable(fields, %{account: account})

      assert depositable.name == fields["name"]
      assert depositable.gateway == fields["gateway"]
      assert depositable.amount == fields["amount"]
      assert depositable.account.id == account.id
    end
  end

  describe "get_depositable/2" do
    test "when give id does not exist" do
      account = account_fixture()

      refute DefaultService.get_depositable(%{id: Ecto.UUID.generate()}, %{account: account})
    end

    test "when given id belongs to a different account" do
      account1 = account_fixture()
      account2 = account_fixture()
      depositable = depositable_fixture(account1)

      refute DefaultService.get_depositable(%{id: depositable.id}, %{account: account2})
    end

    test "when given id" do
      account = account_fixture()
      target_depositable = depositable_fixture(account)

      depositable = DefaultService.get_depositable(%{id: target_depositable.id}, %{account: account})

      assert depositable.id == target_depositable.id
      assert depositable.account.id == account.id
    end
  end

  describe "update_depositable/2" do
    test "when given id does not exist" do
      account = account_fixture()

      identifiers = %{id: Ecto.UUID.generate()}
      opts = %{account: account}
      {:error, error} = DefaultService.update_depositable(identifiers, %{}, opts)

      assert error == :not_found
    end

    test "when given id belongs to a different account" do
      account1 = account_fixture()
      account2 = account_fixture()
      depositable = depositable_fixture(account1)

      identifiers = %{id: depositable.id}
      opts = %{account: account2}

      {:error, error} = DefaultService.update_depositable(identifiers, %{}, opts)

      assert error == :not_found
    end

    test "when given valid id and valid fields" do
      account = account_fixture()
      target_depositable = depositable_fixture(account)

      identifiers = %{id: target_depositable.id}
      fields = %{"name" => Faker.Commerce.product_name()}
      opts = %{account: account}

      {:ok, depositable} = DefaultService.update_depositable(identifiers, fields, opts)

      assert depositable.name == fields["name"]
    end
  end

  describe "delete_depositable/2" do
    test "when given id does not exist" do
      account = account_fixture()

      identifiers = %{id: Ecto.UUID.generate()}
      opts = %{account: account}

      {:error, error} = DefaultService.delete_depositable(identifiers, opts)

      assert error == :not_found
    end

    test "when given id belongs to a different account" do
      account1 = account_fixture()
      account2 = account_fixture()
      depositable = depositable_fixture(account1)

      identifiers = %{id: depositable.id}
      opts = %{account: account2}

      {:error, error} = DefaultService.delete_depositable(identifiers, opts)

      assert error == :not_found
    end

    test "when given valid id" do
      account = account_fixture()
      depositable = depositable_fixture(account)

      identifiers = %{id: depositable.id}
      opts = %{account: account}

      {:ok, depositable} = DefaultService.delete_depositable(identifiers, opts)

      assert depositable
      refute Repo.get(Depositable, depositable.id)
    end
  end

  describe "delete_all_depositable/1" do
    test "given valid account" do
      account = account_fixture()
      test_account = account.test_account
      depositable1 = depositable_fixture(test_account)
      depositable2 = depositable_fixture(test_account)

      :ok = DefaultService.delete_all_depositable(%{account: test_account})

      refute Repo.get(Depositable, depositable1.id)
      refute Repo.get(Depositable, depositable2.id)
    end
  end
end

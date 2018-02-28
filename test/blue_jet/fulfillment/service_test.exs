defmodule BlueJet.Fulfillment.ServiceTest do
  use BlueJet.ContextCase

  alias BlueJet.Identity.Account
  alias BlueJet.Crm.Customer
  alias BlueJet.Goods.Unlockable
  alias BlueJet.Fulfillment.Service
  alias BlueJet.Fulfillment.Unlock

  describe "list_unlock/2" do
    test "unlock for different account is not returned" do
      account = Repo.insert!(%Account{})
      other_account = Repo.insert!(%Account{})
      customer = Repo.insert!(%Customer{
        account_id: other_account.id,
        name: Faker.Name.name()
      })
      unlockable = Repo.insert!(%Unlockable{
        account_id: other_account.id,
        name: Faker.Commerce.product_name()
      })
      Repo.insert!(%Unlock{
        account_id: other_account.id,
        customer_id: customer.id,
        unlockable_id: unlockable.id
      })

      unlocks = Service.list_unlock(%{ customer_id: customer.id }, %{ account: account })
      assert length(unlocks) == 0
    end

    test "valid request" do
      account = Repo.insert!(%Account{})
      customer = Repo.insert!(%Customer{
        account_id: account.id,
        name: Faker.Name.name()
      })
      unlockable = Repo.insert!(%Unlockable{
        account_id: account.id,
        name: Faker.Commerce.product_name()
      })
      Repo.insert!(%Unlock{
        account_id: account.id,
        customer_id: customer.id,
        unlockable_id: unlockable.id
      })

      unlocks = Service.list_unlock(%{ customer_id: customer.id }, %{ account: account })
      assert length(unlocks) == 1
    end
  end

  describe "count_unlock/2" do
    test "valid request" do
      account = Repo.insert!(%Account{})
      customer = Repo.insert!(%Customer{
        account_id: account.id,
        name: Faker.Name.name()
      })
      unlockable = Repo.insert!(%Unlockable{
        account_id: account.id,
        name: Faker.Commerce.product_name()
      })
      Repo.insert!(%Unlock{
        account_id: account.id,
        customer_id: customer.id,
        unlockable_id: unlockable.id
      })

      count = Service.count_unlock(%{ customer_id: customer.id }, %{ account: account })
      assert count == 1
    end
  end

  describe "create_unlock/2" do
    test "when given invalid fields" do
      account = Repo.insert!(%Account{})

      {:error, changeset} = Service.create_unlock(%{}, %{ account: account })
      assert changeset.valid? == false
      assert length(changeset.errors) > 0
    end

    test "when given valid fields" do
      account = Repo.insert!(%Account{})
      customer = Repo.insert!(%Customer{
        account_id: account.id,
        name: Faker.Name.name()
      })
      unlockable = Repo.insert!(%Unlockable{
        account_id: account.id,
        name: Faker.Commerce.product_name()
      })

      fields = %{
        "customer_id" => customer.id,
        "unlockable_id" => unlockable.id
      }

      {:ok, unlock} = Service.create_unlock(fields, %{ account: account })

      assert unlock
    end
  end

  describe "get_unlock/2" do
    test "when given invalid fields" do
      account = Repo.insert!(%Account{})

      refute Service.get_unlock(%{ customer_id: Ecto.UUID.generate() }, %{ account: account })
    end

    test "when given valid fields" do
      account = Repo.insert!(%Account{})
      customer = Repo.insert!(%Customer{
        account_id: account.id,
        name: Faker.Name.name()
      })
      unlockable = Repo.insert!(%Unlockable{
        account_id: account.id,
        name: Faker.Commerce.product_name()
      })
      Repo.insert!(%Unlock{
        account_id: account.id,
        customer_id: customer.id,
        unlockable_id: unlockable.id
      })

      fields = %{
        customer_id: customer.id,
        unlockable_id: unlockable.id
      }

      unlock = Service.get_unlock(fields, %{ account: account })
      assert unlock
    end
  end

  describe "delete_unlock/2" do
    test "when given unlock is nil" do
      {:error, error} = Service.delete_unlock(nil, %{})
      assert error == :not_found
    end

    test "when given unlock is valid" do
      account = Repo.insert!(%Account{})
      customer = Repo.insert!(%Customer{
        account_id: account.id,
        name: Faker.Name.name()
      })
      unlockable = Repo.insert!(%Unlockable{
        account_id: account.id,
        name: Faker.Commerce.product_name()
      })
      unlock = Repo.insert!(%Unlock{
        account_id: account.id,
        customer_id: customer.id,
        unlockable_id: unlockable.id
      })

      {:ok, _} = Service.delete_unlock(unlock, %{ account: account })
    end

    test "when given id is valid" do
      account = Repo.insert!(%Account{})
      customer = Repo.insert!(%Customer{
        account_id: account.id,
        name: Faker.Name.name()
      })
      unlockable = Repo.insert!(%Unlockable{
        account_id: account.id,
        name: Faker.Commerce.product_name()
      })
      unlock = Repo.insert!(%Unlock{
        account_id: account.id,
        customer_id: customer.id,
        unlockable_id: unlockable.id
      })

      {:ok, _} = Service.delete_unlock(unlock.id, %{ account: account })
    end
  end
end
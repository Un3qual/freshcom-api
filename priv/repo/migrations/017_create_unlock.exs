defmodule BlueJet.Repo.Migrations.CreateUnlock do
  use Ecto.Migration

  def change do
    create table(:unlocks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false

      add :custom_data, :map, null: false, default: "{}"
      add :translations, :map, null: false, default: "{}"

      add :source_id, :binary_id
      add :source_type, :string

      add :unlockable_id, references(:unlockables, type: :binary_id, on_delete: :delete_all), null: false
      add :customer_id, references(:customers, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:unlocks, [:account_id, :customer_id])
    create index(:unlocks, [:account_id, :unlockable_id])
  end
end

use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :blue_jet, BlueJetWeb.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :blue_jet, BlueJet.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "blue_jet_test",
  hostname: System.get_env("DB_HOSTNAME"),
  username: System.get_env("DB_USERNAME"),
  pool: Ecto.Adapters.SQL.Sandbox

config :comeonin, :bcrypt_log_rounds, 4

config :blue_jet, BlueJet.GlobalMailer,
  adapter: Bamboo.TestAdapter

config :blue_jet, BlueJet.AccountMailer,
  adapter: Bamboo.TestAdapter

config :blue_jet, :goods, %{
  identity_data: BlueJet.Goods.IdentityDataMock
}

config :blue_jet, :balance, %{
  stripe_client: BlueJet.Balance.StripeClientMock,
  identity_data: BlueJet.Balance.IdentityDataMock
}

config :blue_jet, :catalogue, %{
  identity_data: BlueJet.Catalogue.IdentityDataMock,
  goods_data: BlueJet.Catalogue.GoodsDataMock
}

config :blue_jet, :storefront, %{
  balance_data: BlueJet.Storefront.BalanceDataMock,
  distribution_data: BlueJet.Storefront.DistributionDataMock,
  catalogue_data: BlueJet.Storefront.CatalogueDataMock,
  identity_data: BlueJet.Storefront.IdentityDataMock,
  goods_data: BlueJet.Storefront.GoodsDataMock,
  crm_data: BlueJet.Storefront.CrmDataMock
}

# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :blue_jet,
  ecto_repos: [BlueJet.Repo]

# Configures the endpoint
config :blue_jet, BlueJetWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "wdNdABsV4IpLEClymgU+G6Hb8UXYwFkeDmCnbyC6xunEmhBInx9E0qzEcOrr9mz9",
  render_errors: [view: BlueJetWeb.ErrorView, accepts: ~w(json-api json)],
  pubsub: [name: BlueJet.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Configure phoenix generators
config :phoenix, :generators,
  binary_id: true

config :phoenix, :format_encoders,
  "json-api": Poison

config :mime, :types, %{
  "application/vnd.api+json" => ["json-api"]
}

config :blue_jet, BlueJet.Gettext,
  default_locale: "en"

config :blue_jet, BlueJet.GlobalMailer,
  adapter: Bamboo.PostmarkAdapter,
  api_key: System.get_env("POSTMARK_API_KEY")

config :blue_jet, BlueJet.AccountMailer,
  adapter: Bamboo.SMTPAdapter,
  server: "email-smtp.us-west-2.amazonaws.com",
  port: System.get_env("SMTP_PORT"),
  username: System.get_env("SMTP_USERNAME"), # or {:system, "SMTP_USERNAME"}
  password: System.get_env("SMTP_PASSWORD"), # or {:system, "SMTP_PASSWORD"}
  tls: :always, # can be `:always` or `:never`
  # allowed_tls_versions: [:"tlsv1", :"tlsv1.1", :"tlsv1.2"], # or {":system", ALLOWED_TLS_VERSIONS"} w/ comma seprated values (e.g. "tlsv1.1,tlsv1.2")
  ssl: false, # can be `true`
  retries: 0

defmodule JaKeyFormatter do
  def camelize(key) do
    Inflex.camelize(key, :lower)
  end

  def underscore(key) do
    Inflex.underscore(key)
  end
end

config :ja_serializer,
  key_format: {:custom, JaKeyFormatter, :camelize, :underscore}

config :ex_aws, region: System.get_env("AWS_REGION")


config :blue_jet, :s3, prefix: "uploads"

config :blue_jet, :identity, %{
  listeners: [BlueJet.Balance, BlueJet.Notification]
}

config :blue_jet, :goods, %{
  identity_data: BlueJet.Identity.Data,
}

config :blue_jet, :balance, %{
  stripe_client: BlueJet.Stripe.Client,
  identity_data: BlueJet.Identity.Data,
  listeners: [BlueJet.Storefront, BlueJet.Crm]
}

config :blue_jet, :catalogue, %{
  identity_data: BlueJet.Identity.Data,
  goods_data: BlueJet.Goods.Data
}

config :blue_jet, :storefront, %{
  balance_data: BlueJet.Balance.Data,
  distribution_data: BlueJet.Distribution.Data,
  catalogue_data: BlueJet.Catalogue.Data,
  identity_data: BlueJet.Identity.Data,
  goods_data: BlueJet.Goods.Data,
  crm_data: BlueJet.Crm.Data
}

config :blue_jet, :distribution, %{
  listeners: [BlueJet.Storefront]
}

# config :stripe, secret_key: System.get_env("STRIPE_SECRET_KEY")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"

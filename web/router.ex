defmodule BlueJet.Router do
  use BlueJet.Web, :router

  pipeline :api do
    plug :accepts, ["json-api"]
    plug BlueJet.Plugs.CORS
    plug BlueJet.Plugs.Authentication, ["/v1/token"]
    plug BlueJet.Plugs.Locale, "en"
    plug BlueJet.Plugs.Pagination
    plug BlueJet.Plugs.Fields
    plug BlueJet.Plugs.ContentTypeNegotiation
    plug JaSerializer.Deserializer
  end

  scope "/v1/", BlueJet do
    pipe_through :api

    options "/*path", WelcomeController, :options

    resources "/token", TokenController, only: [:create]

    resources "/accounts", AccountController, except: [:new, :edit]
    resources "/members", AccountMemberController, except: [:new, :edit]
    resources "/users", UserController, except: [:new, :edit]

    resources "/external_files", ExternalFileController, except: [:new, :edit]
    resources "/external_file_collections", ExternalFileCollectionController, except: [:new, :edit] do
      resources "/memberships", ExternalFileCollectionMembershipController, only: [:create]
    end
    resources "/external_file_collection_memberships", ExternalFileCollectionMembershipController, only: [:index, :update, :delete]

    resources "/customers", CustomerController, except: [:new, :edit]

    resources "/skus", SkuController, except: [:new, :edit]
    resources "/unlockables", UnlockableController, except: [:new, :edit]
    resources "/products", ProductController, except: [:new, :edit] do
      resources "/items", ProductItemController, only: [:create]
    end
    resources "/product_items", ProductItemController, except: [:new, :edit, :create] do
      resources "/prices", PriceController, only: [:create]
    end
    resources "/prices", PriceController, except: [:new, :edit, :create]
  end
end

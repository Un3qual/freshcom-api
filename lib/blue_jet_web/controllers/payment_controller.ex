defmodule BlueJetWeb.PaymentController do
  use BlueJetWeb, :controller

  alias JaSerializer.Params
  alias BlueJet.Balance

  action_fallback BlueJetWeb.FallbackController

  plug :scrub_params, "data" when action in [:create, :update]

  def index(conn = %{ assigns: assigns }, params) do
    request = %ContextRequest{
      vas: assigns[:vas],
      search: params["search"],
      filter: assigns[:filter],
      pagination: %{ size: assigns[:page_size], number: assigns[:page_number] },
      preloads: assigns[:preloads],
      locale: assigns[:locale]
    }

    case Balance.list_payment(request) do
      {:ok, %{ data: payments, meta: meta }} ->
        render(conn, "index.json-api", data: payments, opts: [meta: camelize_map(meta), include: conn.query_params["include"]])

      other -> other
    end
  end

  def create(conn = %{ assigns: assigns }, %{ "data" => data = %{ "type" => "Payment" } }) do
    request = %ContextRequest{
      vas: assigns[:vas],
      fields: Params.to_attributes(data),
      preloads: assigns[:preloads]
    }

    case Balance.create_payment(request) do
      {:ok, %{ data: payment, meta: meta }} ->
        conn
        |> put_status(:created)
        |> render("show.json-api", data: payment, opts: [meta: camelize_map(meta), include: conn.query_params["include"]])

      {:error, %{ errors: errors }} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:errors, data: extract_errors(errors))

      other -> other
    end
  end

  def show(conn = %{ assigns: assigns }, %{ "id" => id }) do
    request = %ContextRequest{
      vas: assigns[:vas],
      params: %{ "id" => id },
      preloads: assigns[:preloads],
      locale: assigns[:locale]
    }

    case Balance.get_payment(request) do
      {:ok, %{ data: payment, meta: meta }} ->
        render(conn, "show.json-api", data: payment, opts: [meta: camelize_map(meta), include: conn.query_params["include"]])

      other -> other
    end
  end

  def update(conn = %{ assigns: assigns }, %{ "id" => id, "data" => data = %{ "type" => "Payment" } }) do
    request = %ContextRequest{
      vas: assigns[:vas],
      params: %{ "id" => id },
      fields: Params.to_attributes(data),
      preloads: assigns[:preloads],
      locale: assigns[:locale]
    }

    case Balance.update_payment(request) do
      {:ok, %{ data: payment, meta: meta }} ->
        render(conn, "show.json-api", data: payment, opts: [meta: camelize_map(meta), include: conn.query_params["include"]])

      {:error, %{ errors: errors }} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:errors, data: extract_errors(errors))

      other -> other
    end
  end

  def delete(conn = %{ assigns: assigns }, %{ "id" => id }) do
    request = %ContextRequest{
      vas: assigns[:vas],
      params: %{ "id" => id }
    }

    case Balance.delete_payment(request) do
      {:ok, _} -> send_resp(conn, :no_content, "")

      {:error, %{ errors: errors }} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:errors, data: extract_errors(errors))

      other -> other
    end
  end
end

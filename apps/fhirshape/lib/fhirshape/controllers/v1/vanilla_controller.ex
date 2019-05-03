defmodule Fhirshape.V1.VanillaController do
  use Fhirshape, :controller

  alias Fhirshape.Healthcare
  alias Fhirshape.Healthcare.Vanilla
  action_fallback(Fhirshape.FallbackController)

  def index(conn, params) do
    pgpairs = params["page"]

    limit =
      if pgpairs != nil and pgpairs["size"] != nil,
        do:
          (case Integer.parse(pgpairs["size"]) do
             :error -> 25
             # negatives are nonsense, should error?
             {num, _} when num < 1 -> 25
             # greater than zeros are fine
             {num, _} when num > 0 -> num
           end),
        else: 25

    offset =
      if pgpairs != nil and pgpairs["number"] != nil,
        do:
          (case Integer.parse(pgpairs["number"]) do
             :error -> 1
             # negatives are nonsense, should error?
             {num, _} when num < 1 -> 1
             # greater than zeros are fine
             {num, _} when num > 0 -> num
           end),
        else: 1

    [sort_field, order] =
      if params["sort"] == nil,
        do: ["id", :ASC],
        else:
          (case String.downcase(params["sort"]) do
             "ts" -> ["ts", :ASC]
             "-ts" -> ["ts", :DESC]
             "-id" -> ["id", :DESC]
             _ -> ["id", :ASC]
           end)

    page =
      if limit == 0,
        do: nil,
        else: %{limit: limit, offset: offset, order: order, sort_field: sort_field}

    {vanillas, paginate} = Healthcare.list_vanilla(conn.assigns.resource_type, page)
    count = to_string(length(vanillas))

    conn
    |> put_resp_header("x-total-count", count)
    |> render("index.json", %{vanillas: vanillas, paginate: paginate})
  end

  def create(conn, params) do
    params = Map.put_new(params, :resource_type, conn.assigns.resource_type)

    case Healthcare.create_vanilla(params) do
      {:error, descr} ->
        conn
        |> put_status(:bad_request)
        |> text(descr)

      {:ok, %Vanilla{} = vanilla} ->
        tree = Jason.decode!(vanilla.resource)
        render(conn, "show.json", vanilla: tree)
    end
  end

  def show(conn, %{"id" => id}) do
    case Healthcare.get_vanilla(id, conn.assigns.resource_type) do
      nil ->
        vanilla_not_found(conn)

      vanilla ->
        tree = Jason.decode!(vanilla.resource)
        render(conn, "show.json", vanilla: tree)
    end
  end

  def update(conn, params) do
    case Healthcare.get_vanilla(params["id"], conn.assigns.resource_type) do
      nil ->
        vanilla_not_found(conn)

      vanilla ->
        ## params = Map.put(params, :resource_type, conn.assigns.resource_type)
        rtype = String.downcase(conn.assigns.resource_type)

        # DEBUG DEBUG
        IO.inspect(rtype, label: "downcased")
        IO.inspect(params, label: "hc-upd params")

        case Healthcare.update_vanilla(vanilla, params[rtype]) do
          {:ok, %Vanilla{} = vanilla} ->
            tree = Jason.decode!(vanilla.resource)
            render(conn, "show.json", vanilla: tree)

          {:error, descr} ->
            resource_type_required(conn, descr)
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Healthcare.get_vanilla(id, conn.assigns.resource_type) do
      nil ->
        vanilla_not_found(conn)

      vanilla ->
        with {:ok, %Vanilla{}} <- Healthcare.delete_vanilla(vanilla) do
          tree = Jason.decode!(vanilla.resource)
          render(conn, "show.json", vanilla: tree)
        end
    end
  end

  defp vanilla_not_found(conn) do
    conn
    |> put_status(:not_found)
    |> text("#{conn.assigns.resource_type} not found")
  end

  defp resource_type_required(conn, descr) do
    conn
    |> put_status(:bad_request)
    |> text(descr)
  end
end

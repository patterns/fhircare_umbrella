defmodule Fhirshape.V1.VanillaController do
  use Fhirshape, :controller

  alias Fhirshape.Healthcare
  alias Fhirshape.Healthcare.Vanilla
  action_fallback(Fhirshape.FallbackController)

  def index(conn, _params) do
    IO.inspect(conn, label: "Index params")
  end

  def create(conn, params) do
    params = Map.put_new(params, :resource_type, conn.assigns.resource_type)

    case Healthcare.create_vanilla(params) do
      {:error, descr} ->
        conn
        |> put_status(:bad_request)
        |> text(descr)

      {:ok, %Vanilla{} = vanilla} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(:created, [vanilla.resource])
    end
  end

  def show(conn, %{"id" => id}) do
    case Healthcare.get_vanilla(id, conn.assigns.resource_type) do
      nil ->
        vanilla_not_found(conn)

      vanilla ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, [vanilla.resource])
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
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, [vanilla.resource])

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
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(200, [vanilla.resource])
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

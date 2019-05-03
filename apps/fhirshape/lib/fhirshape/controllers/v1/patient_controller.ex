defmodule Fhirshape.V1.PatientController do
  use Fhirshape, :controller

  alias Fhirshape.Healthcare
  alias Fhirshape.Healthcare.Patient
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

    {patients, paginate} = Healthcare.list_patients(page)
    count = to_string(length(patients))

    conn
    |> put_resp_header("x-total-count", count)
    |> render("index.json", %{patients: patients, paginate: paginate})
  end

  def create(conn, %{"patient" => patient_params}) do
    case Healthcare.create_patient(patient_params) do
      {:error, descr} ->
        conn
        |> put_status(:bad_request)
        |> text(descr)

      {:ok, %Patient{} = patient} ->
        tree = Jason.decode!(patient.resource)
        render(conn, "show.json", patient: tree)
    end
  end

  def show(conn, %{"id" => id}) do
    case Healthcare.get_patient(id) do
      nil ->
        patient_not_found(conn)

      patient ->
        tree = Jason.decode!(patient.resource)
        render(conn, "show.json", patient: tree)
    end
  end

  def update(conn, %{"id" => id, "patient" => patient_params}) do
    case Healthcare.get_patient(id) do
      nil ->
        patient_not_found(conn)

      patient ->
        case Healthcare.update_patient(patient, patient_params) do
          {:ok, %Patient{} = patient} ->
            tree = Jason.decode!(patient.resource)
            render(conn, "show.json", patient: tree)

          {:error, descr} ->
            patient_name_required(conn, descr)
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Healthcare.get_patient(id) do
      nil ->
        patient_not_found(conn)

      patient ->
        with {:ok, %Patient{}} <- Healthcare.delete_patient(patient) do
          tree = Jason.decode!(patient.resource)
          render(conn, "show.json", patient: tree)
        end
    end
  end

  defp patient_not_found(conn) do
    conn
    |> put_status(:not_found)
    |> text("Patient not found")
  end

  defp patient_name_required(conn, descr) do
    conn
    |> put_status(:bad_request)
    |> text(descr)
  end
end

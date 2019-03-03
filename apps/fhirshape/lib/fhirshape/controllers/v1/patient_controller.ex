defmodule Fhirshape.V1.PatientController do
  use Fhirshape, :controller

  alias Fhirshape.Healthcare
  alias Fhirshape.Healthcare.Patient
  action_fallback(Fhirshape.FallbackController)

  def index(conn, _params) do
    IO.inspect(conn, label: "Patient list params")
  end

  def create(conn, %{"patient" => patient_params}) do
    case Healthcare.create_patient(patient_params) do
      {:error, descr} ->
        conn
        |> put_status(:bad_request)
        |> text(descr)

      {:ok, %Patient{} = patient} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(:created, [patient.resource])
    end
  end

  def show(conn, %{"id" => id}) do
    case Healthcare.get_patient(id) do
      nil ->
        patient_not_found(conn)

      patient ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, [patient.resource])
    end
  end

  def update(conn, %{"id" => id, "patient" => patient_params}) do
    case Healthcare.get_patient(id) do
      nil ->
        patient_not_found(conn)

      patient ->
        case Healthcare.update_patient(patient, patient_params) do
          {:ok, %Patient{} = patient} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, [patient.resource])

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
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(200, [patient.resource])
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

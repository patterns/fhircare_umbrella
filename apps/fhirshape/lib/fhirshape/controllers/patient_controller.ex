defmodule Fhirshape.PatientController do
  use Fhirshape, :controller

  alias Fhirshape.Healthcare
  alias Fhirshape.Healthcare.Patient

  action_fallback Fhirshape.FallbackController

  def index(conn, _params) do
    patients = Healthcare.list_patients()
    render(conn, "index.json", patients: patients)
  end

  def create(conn, %{"patient" => patient_params}) do
    with {:ok, %Patient{} = patient} <- Healthcare.create_patient(patient_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.patient_path(conn, :show, patient))
      |> render("show.json", patient: patient)
    end
  end

  def show(conn, %{"id" => id}) do
    patient = Healthcare.get_patient!(id)
    #### render(conn, "show.json", patient: patient)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, [patient.resource])
  end

  def update(conn, %{"id" => id, "patient" => patient_params}) do
    patient = Healthcare.get_patient!(id)

    with {:ok, %Patient{} = patient} <- Healthcare.update_patient(patient, patient_params) do
      #### render(conn, "show.json", patient: patient)
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, [patient.resource])
    end
  end

  def delete(conn, %{"id" => id}) do
    patient = Healthcare.get_patient!(id)

    with {:ok, %Patient{}} <- Healthcare.delete_patient(patient) do
      send_resp(conn, :no_content, "")
    end
  end
end

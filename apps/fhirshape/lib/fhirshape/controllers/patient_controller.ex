defmodule Fhirshape.PatientController do
  use Fhirshape, :controller

  alias Fhirshape.Healthcare
  alias Fhirshape.Healthcare.Patient

  action_fallback Fhirshape.FallbackController

  def index(conn, _params) do

  end

  def create(conn, %{"patient" => patient_params}) do

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

  end
end
